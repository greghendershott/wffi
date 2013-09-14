#lang racket

(require net/uri-codec
         (planet gh/http/request)
         (planet gh/http/head)
         json
         "api.rkt"
         "dict-merge.rkt"
         "markdown.rkt"
         "split.rkt"
         (for-syntax racket/syntax
                     racket/string
                     racket/match
                     racket/path
                     "api.rkt"
                     "markdown.rkt"))

(provide make-api-dict-procedure
         make-api-rest-procedure
         make-api-keyword-procedure
         api-func-inputs
         apply-dict
         wffi-kwd-proc
         wffi-rest-proc
         wffi-dict-proc
         wffi-lib
         wffi-obj
         wffi-define-all
         dict-refs
         check-response/json
         api-func->markdown
         (struct-out api)
         (struct-out api-func))

(define/contract (dict->request a d)
  (api-func? dict? . -> . (values string? string? dict? (or/c #f bytes?)))
  (define (to-conses x)
    ;; (or/c keyval? optional?) -> (listof (or/c #f (cons/c symbol? string?)))
    (define (ref name d key)
      (unless (dict-has-key? d key)
        (error 'dict->request "Missing required parameter ~a." name))
      (match (dict-ref d key)
        [(list vs ...) (for/list ([v vs])
                         (cons name (~a v)))]
        [v (list (cons name (~a v)))]))
    (match x
      [(keyval k (constant v)) (list (cons k v))]
      [(keyval k (variable v)) (ref k d v)]
      [(optional (keyval k (variable v)))
       (cond [(dict-has-key? d v) (ref k d v)]
             [else #f])]
      [(optional (keyval k (constant v)))
       (cond [(dict-has-key? d k) (ref k d k)]
             [else (list (cons k v))])]
      [else (error 'dict->request "Unknown value: ~v" x)]))
  (match-define (api-func _ _ m p q h _) a)
  (define path
    (string-join (for/list ([x p])
                   (match x
                     [(? string? s) s]
                     [(variable k) (format "~a" (dict-ref d k))]
                     [else (error 'dict->request)]))
                 ""))
  (define query (alist->form-urlencoded (append* (filter-map to-conses q))))
  (define method (string-upcase (symbol->string m)))
  (define path+query (string-append path
                                    (cond [(string=? "" query) ""]
                                          [else (string-append "?" query)])))
  (define heads (append* (filter-map to-conses h)))
  ;; (define body (alist->form-urlencoded (filter-map to-cons b)))
  (define body (dict-ref d 'entity #""))
  (values method path+query heads body))

;; ;; Example:
;; (require racket/runtime-path)
;; (define-runtime-path example.md "example.md")
;; (define ex (wffi-obj (wffi-lib example.md) "Example GET API"))
;; (dict->request ex (hasheq 'user "Greg"
;;                           'item 1
;;                           'qa "qa"
;;                           'qb '("qb1" "qb2") ;repeats OK as list
;;                           'Host "foobar.com"
;;                           'Authorization "blah"
;;                           'Date "today"
;;                           'Cookie '("cookie1" "cookie2") ;repeats OK
;;                           'alias "foo"
;;                           'Optional-Var 999
;;                           'Optional-Const 1
;;                           'entity #"wah wah wah"
;;                           ))

;; Client: From an HTTP response that has already been matched with a
;; api-func?, fill a dict? with all of the parameterized values.
(define/contract (response->dict a h e)
  (api-func? string? (or/c bytes? string?) . -> . dict?)
  (dict-merge
   `([HTTP-Ver . ,(extract-http-ver h)]
     [HTTP-Code . ,(extract-http-code h)]
     [HTTP-Text ,(extract-http-text h)])
   (heads-string->dict h)
   (cond [(regexp-match?
           #px"Content-Type\\s*:\\s*application/x-www-form-urlencoded"
           h)
          (for/hash ([x (regexp-split #rx"&" e)] #:when (not (string=? "" x)))
            (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
                      (values (string->symbol k) v)]))]
         [else (hash)])
   `([entity . ,e])
   ))

;; (response->dict
;;  ex
;;  (string-join (list "HTTP/1.1 200 OK"
;;                     "Date: today"
;;                     "Content-Type: application/x-www-form-urlencoded"
;;                     "Content-Length: 7"
;;                     ""
;;                     "")
;;               "\r\n")
;;  "a=1&b=2")

(define (path-syms xs)
  (filter-map (lambda (x)
                (match x
                  [(list 'VARIABLE v) v]
                  [else #f]))
              xs))

(define (syms xs)
  (for/fold ([req '()]
             [opt '()])
            ([x xs])
    (match x
      [(list k (list 'VARIABLE v)) (values (cons v req) opt)]
      [(list 'OPTIONAL (list _ (list 'VARIABLE v))) (values req (cons v opt))]
      [(list 'OPTIONAL (list k (list 'CONSTANT _))) (values req (cons k opt))]
      [else (values req opt)])))

(define (symbol<=? a b)
  (string<=? (symbol->string a) (symbol->string b)))

(define/contract (api-func-inputs a)
  (api-func? . -> . (values (listof symbol?) (listof symbol?)))
  (match-define (api-func _ _ m p q h _) a)
  (define path-req (path-syms p))
  (define-values (req opt) (syms (append q h)))
  (values (sort (append path-req req) symbol<=?)
          (sort opt symbol<=?)))

(define (api-func-outputs a)
  (define h (api-func-resp-head a))
  (define-values (req opt) (syms (append h)))
  (values (sort req symbol<=?)
          (sort opt symbol<=?)))

(define/contract (do-request a d endpoint)
  (api-func? dict? string? . -> . dict?)
  (define-values (scheme host port path query fragment) (split-uri endpoint))
  (define-values (method path+query heads data) (dict->request a d))
  (define uri (string-append endpoint path+query))
  (call/output-request "1.1"
                       method
                       uri
                       data
                       #f
                       (maybe-dict-set* heads
                                        'Host host
                                        'Date (seconds->gmt-string)
                                        'Connection "close")
                       (lambda (in h)
                         (response->dict a h (read-entity/bytes in h)))))

(define symbol->keyword (compose1 string->keyword symbol->string))
(define keyword->symbol (compose1 string->symbol keyword->string))
(define (keyword<=? a b)
  (string<=? (keyword->string a) (keyword->string b)))

;; This is the fundamental procedure: dict? -> dict?
(define/contract (make-api-dict-procedure a endpoint)
  (api-func? string? . -> . (dict? . -> . dict?))
  (lambda (d)
    (do-request a d endpoint)))

;; This makes a function where the dict may be supplied as key/value
;; pairs as with `hash`: 'key value ... ... -> dict?
(define (make-api-rest-procedure a endpoint)
  (api-func? string? . -> . procedure?)
  (compose1 (make-api-dict-procedure a endpoint)
            hasheq))

;; This makes a function where they're supplied as keyword arguments:
;; #:keyword value ... ... -> dict?
(define/contract (make-api-keyword-procedure a endpoint)
  (api-func? string? . -> . procedure?)
  (define f (make-keyword-procedure
             (lambda (kws vs . rest)
               (do-request a
                           (map cons
                                (map keyword->symbol kws)
                                vs)
                           endpoint))))
  (define-values (req opt) (api-func-inputs a))
  (define req-kws (map symbol->keyword req))
  (define opt-kws (map symbol->keyword opt))
  (define all-kws (sort (append req-kws opt-kws) keyword<=?))
  ;;(printf "Required: ~v\nOptional: ~v\n" req-kws opt-kws)
  (procedure-reduce-keyword-arity f 0 req-kws all-kws))

;; Given a function taking solely keyword arguments, and a dictionary
;; of symbol? => any/c, do a keyword-apply treating the dictionary
;; keys as keywords.
(define (apply-dict f d)
  (define xs (sort (for/list ([(k v) (in-dict d)])
                     (cons (symbol->keyword k) v))
                   keyword<?
                   #:key car))
  (define kws (map car xs))
  (define vs (map cdr xs))
  (keyword-apply f kws vs (list)))

(define/contract (wffi-dict-proc lib name)
  (api? string? . -> . (dict? . -> . dict?))
  (make-api-dict-procedure (wffi-obj lib name) (api-endpoint lib)))

(define/contract (wffi-rest-proc lib name)
  (api? string? . -> . procedure?)
  (make-api-rest-procedure (wffi-obj lib name) (api-endpoint lib)))

(define/contract (wffi-kwd-proc lib name)
  (api? string? . -> . procedure?)
  (make-api-keyword-procedure (wffi-obj lib name) (api-endpoint)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr. Else raise an error.
;;
;; This may be supplied as the `post` arg to `define-all-procs/dict`
(define (check-response/json who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200)
         (match (dict-ref d 'Content-Type)
           [(pregexp "^application/json") (bytes->jsexpr (dict-ref d 'entity))]
           [else (dict-ref d 'entity)])]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (chain . fs)
  (apply compose1 (reverse fs)))

(begin-for-syntax
 (define (racketize s)
   ;; "Foo Bar" -> "foo-bar"
   ;; "Foo.bar" -> "foo-bar"
   (string-join (map string-downcase (regexp-split #rx"[ .]" s))
                "-"))

 (define (no-md-suffix s)
   (match s
     [(regexp "^(.+?)-md$" (list _ base)) base]
     [else s])))

;; Load the wffi definition in lib-name, define an ID for the lib, and
;; define a wrapper function for everything in the lib.  Each wrapper
;; function is defined as a composition sandwich: `before`, HTTP
;; request, `after`. Typically `before` will add to the dict any
;; common parameters (such as an API key or Authorization for the
;; service), and `after` will process the response (such as doing
;; bytes->jsexpr for a successful response or calling `error` for a
;; failure response).
;;
;; lib-name: string? just base name (e.g. "foo.md") relative to source
;; before:   (dict? -> dict?)
;; after:    (symbol? dict? -> dict?)
(define-syntax (wffi-define-all stx)
  (syntax-case stx ()
    [(_ LIB-NAME BEFORE AFTER)
     (let* ([lib-path (build-path (path-only (syntax-source stx))
                                  (syntax-e #'LIB-NAME))]
            [lib (wffi-lib lib-path)])
       (with-syntax ([LIB-PATH lib-path]
                     [LIB-ID (format-id #'LIB-NAME
                                        "~a-lib"
                                        (no-md-suffix
                                         (racketize (syntax-e #'LIB-NAME))))])
         #`(begin
             (define LIB-ID (wffi-lib LIB-PATH))
             #,@(for/list ([func (api-funcs lib)])
                  (with-syntax ([NAME (api-func-name func)]
                                [ID (format-id stx
                                               "~a"
                                               (racketize
                                                (api-func-name func)))])
                    #'(define ID (chain hash
                                        BEFORE
                                        (wffi-dict-proc LIB-ID NAME)
                                        (lambda (x) (AFTER (syntax-e #'NAME) x))
                                        )))))))]))
