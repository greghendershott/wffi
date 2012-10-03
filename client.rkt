#lang racket

(require net/uri-codec
         (planet gh/http/request)
         (planet gh/http/head)
         "api.rkt"
         "markdown.rkt"
         "split.rkt"
         "dict-merge.rkt")
         
(provide make-api-keyword-procedure
         api-inputs
         apply-dict
         wffi-kwd-proc
         wffi-rest-proc
         wffi-dict-proc
         wffi-lib
         wffi-obj
         api->markdown
         (struct-out api))

(define/contract (dict->request a d)
  (api? dict? . -> . (values string? string? dict? (or/c #f bytes?)))
  (define (to-cons x)
    (match x
      [(keyval k (constant v)) (cons k v)]
      [(keyval k (variable v)) (cons k (format "~a" (dict-ref d v)))]
      [(optional (keyval k (variable v)))
       (cond [(dict-has-key? d v) (cons k (format "~a" (dict-ref d v)))]
             [else #f])]
      [(optional (keyval k (constant v)))
       (cond [(dict-has-key? d k) (cons k (format "~a" (dict-ref d k)))]
             [else (cons k v)])]
      [else (error 'dict->request "~v" x)]))
  (match-define (api _ _ _ m p q h _) a)
  (define path
    (string-join (for/list ([x p])
                   (match x
                     [(? string? s) s]
                     [(variable k) (format "~a" (dict-ref d k))]
                     [else (error 'dict->request)]))
                 ""))
  (define query (alist->form-urlencoded (filter-map to-cons q)))
  (define method (string-upcase (symbol->string m)))
  (define path+query (string-append path
                                    (cond [(string=? "" query) ""]
                                          [else (string-append "?" query)])))
  (define heads (filter-map to-cons h))
  ;; (define body (alist->form-urlencoded (filter-map to-cons b)))
  (values method path+query heads #f))

#;
(define ex (wffi-obj (wffi-lib "example.md") "Example GET API"))
#;
(dict->request ex (hash 'user "Greg"
                        'item 1
                        'qa "qa"
                        'qb "qb"
                        'Host "foobar.com"
                        'Authorization "blah"
                        'Date "today"
                        'alias "foo"
                        'Optional-Var 999
                        'Optional-Const 1
                        ))

;; Client: From an HTTP response that has already been matched with a
;; api?, fill a dict? with all of the parameterized values.
(define/contract (response->dict a h e)
  (api? string? (or/c bytes? string?) . -> . dict?)
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

#;
(response->dict
 ex
 (string-join (list "HTTP/1.1 200 OK"
                    "Date: today"
                    "Content-Type: application/x-www-form-urlencoded"
                    "Content-Length: 7"
                    ""
                    "")
              "\r\n")
 "a=1&b=2")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

(define/contract (api-inputs a)
  (api? . -> . (values (listof symbol?) (listof symbol?)))
  (match-define (api _ _ _ m p q h _) a)
  (define path-req (path-syms p))
  (define-values (req opt) (syms (append q h)))
  (values (sort (append path-req req) symbol<=?)
          (sort opt symbol<=?)))

;;(api-inputs ex)

(define (api-outputs a)
  (define h (api-resp-head a))
  (define-values (req opt) (syms (append h)))
  (values (sort req symbol<=?)
          (sort opt symbol<=?)))

;;(api-outputs ex)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; for use by client

(define/contract (do-request a d endpoint)
  (api? dict? (-> string?) . -> . dict?)
  (define-values (method path+query heads data) (dict->request a d))
  (define uri (string-append (endpoint) path+query))
  (call/input-request "1.1" method uri heads
                      (lambda (in h)
                        (response->dict a h (read-entity/bytes in h)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define symbol->keyword (compose1 string->keyword symbol->string))
(define keyword->symbol (compose1 string->symbol keyword->string))
(define (keyword<=? a b)
  (string<=? (keyword->string a) (keyword->string b)))

;; This is the fundamental procedure: dict? -> dict?
(define/contract (make-api-dict-procedure a endpoint)
  (api? (-> string?) . -> . (dict? . -> . dict?))
  (lambda (d)
    (do-request a d endpoint)))

;; This makes a function where the dict may be supplied as key/value
;; pairs as with `hash`: 'key value ... ... -> dict?
(define (make-api-rest-procedure a endpoint)
  (api? (-> string?) . -> . procedure?)
  (compose1 (make-api-dict-procedure a endpoint)
            hash))

;; This makes a function where they're supplied as keyword arguments:
;; #:keyword value ... ... -> dict?
(define/contract (make-api-keyword-procedure a endpoint)
  (api? (-> string?) . -> . procedure?)
  (define f (make-keyword-procedure
             (lambda (kws vs . rest)
               (do-request a
                           (map cons
                                (map keyword->symbol kws)
                                vs)
                           endpoint))))
  (define-values (req opt) (api-inputs a))
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define/contract (wffi-dict-proc lib name endpoint)
  ((listof api?) string? (-> string?) . -> . (dict? . -> . dict?))
  (make-api-dict-procedure (wffi-obj lib name) endpoint))

(define/contract (wffi-rest-proc lib name endpoint)
  ((listof api?) string? (-> string?) . -> . procedure?)
  (make-api-rest-procedure (wffi-obj lib name) endpoint))

(define/contract (wffi-kwd-proc lib name endpoint)
  ((listof api?) string? (-> string?) . -> . procedure?)
  (make-api-keyword-procedure (wffi-obj lib name) endpoint))
