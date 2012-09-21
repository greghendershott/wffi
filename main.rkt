#lang racket

(require (planet gh/http/request)
         racket/splicing
         racket/stxparam
         rackunit
         "dict-merge.rkt"
         )
         
(provide apis
         (struct-out api)
         ;; defapi
         dict->request
         request->dict
         dict->response
         response->dict
         dispatch
         try-api?
         request-matches-api?
         api-inputs
         api-outputs
         api->markdown
         make-api-keyword-procedure
         apply-dict
         wffi-lib
         get-wffi-obj
         )

(struct api
        (name            ;string?
         desc            ;string?
         req             ;string?
         resp            ;string?
         ;; For using to implement a server:
         route-px        ;pregexp?
         path-px         ;pregexp?
         ;; Request:
         path-syms       ;(listof symbol?)
         query-dict      ;(dict string? symbol?)
         head-dict       ;(dict string? symbol?)
         form-dict       ;(dict string? symbol?)
         ;; Response:
         resp-head-dict  ;(dict string? symbol)
        ) #:transparent)

(define apis (make-parameter (hash))) ;hashof api? => (dict? -> dict?)
(define (register-api! a proc)
  (hash-set! apis a proc))
             
;; (define-syntax-parameter d
;;   (lambda (stx)
;;     (raise-syntax-error #f "d is only bound inside an api handler")))
;; (provide d)

;; (define-syntax-rule (defapi name title [desc ...] [req ...] [resp ...]
;;                       body0 body ...)
;;   (begin
;;     (define name (init-api (lambda (dict)
;;                              (splicing-syntax-parameterize
;;                                  ([d (make-rename-transformer #'dict)])
;;                                body0 body ...))
;;                            `title
;;                            (multi-line `(desc ...))
;;                            (multi-line `(req ...))
;;                            (multi-line `(resp ...))))
;;     (register-api! name)))

;; (define (multi-line xs)
;;   (string-append (string-join xs "\n") "\n"))

(define/contract (init-api name doc req resp)
  (string? string? string? string?  . -> . api?)
  (define-values (method path query heads entity) (split-request req))
  (define rx #rx"{(.+?)}")
  (define path-syms (for/list ([x (in-list (or (regexp-match* rx path) '()))])
                        (string->symbol (cadr (regexp-match #rx"^{(.+)}$" x)))))
  (define path-re (regexp-replace* rx path "(.+?)"))
  (define route-px (pregexp
                    (string-append "^"
                                   "(?i:" (regexp-quote method) ")"
                                   "\\s+"
                                   path-re
                                   "\\s+")))
  (define query-dict (string->dict query "&" "="))
  (define head-dict (string->dict heads "\n" ":"))
  (define form-dict (string->dict entity "&" "="))
  (define-values (resp-status resp-heads resp-entity) (split-response resp))
  (define resp-head-dict (string->dict resp-heads "\n" ":"))
  (api name
       doc
       req
       resp
       route-px
       (pregexp path-re)
       path-syms
       query-dict
       head-dict
       form-dict
       resp-head-dict
       ))

(define/contract (split-request req)
  (string? . -> . (values string? string? string? string? string?))
  (match req
    [(pregexp "^(.+?)\\s+(.+?)\n(.+?)$" (list _ m p+q h+e))
     ;; I couldn't figure out the regexp to split p and q in the
     ;; first place, so split them now.
     (define-values (p q)
       (match (regexp-split (regexp-quote "?") p+q)
         [(list p q) (values p q)]
         [(list p) (values p "")]
         [(list) (values "" "")]
         [else (error 'split-request "can't determine path and query")]))
     ;; I couldn't figure out the regexp to split h and e in the
     ;; first place, so split them now.
     (define-values (h e)
       (match (regexp-split "\n\n" h+e)
         [(list h e) (values h e)]
         [(list h) (values h "")]
         [(list) (values "" "")]
         [else (error 'split-request
                      "can't determine heads and entity:\n~s" h+e)]))
     (values m p q h e)]
    [else (error 'split-request "can't parse request template")]))  

(define/contract (split-response resp)
  (string? . -> . (values string? string? string?))
  (match resp
    [(pregexp "^(.+?)\n(.*)\n\n(.*)$" (list _ s h e)) (values s h e)]
    [else (error 'split-response "can't determine heads and entity ~s" resp)]))
  ;; (match (regexp-split "\n\n" req)
  ;;   [(list h e) (values h e)]
  ;;   [(list h) (values h "")]
  ;;   [(list) (values "" "")]
  ;;   [else (error 'split-response "can't determine heads and entity")]))

;; `f' is called so that it may add some values to the dict (they
;; don't need to be the original values passed to it) and return the
;; new dict. If it doesn't want to add any values at all, it can
;; simply return the original dict.
(define/contract (k/v-string->dict str sep eq-delim curly-val? f)
  (string? string? string? boolean? (dict? string? string? . -> . dict?)
           . -> . dict?)
  (define px (pregexp (string-append "^(\\S+?)\\s*"
                                     (regexp-quote eq-delim)
                                     "\\s*"
                                     (if curly-val? "\\{" "")
                                     "(.+?)" ;;"(\\S+?)"
                                     (if curly-val? "\\}" "")
                                     "[\r\n]*$")))
  (for/fold ([d '()]) ;use an alist instead of hash; few items
            ([x (in-list (regexp-split (regexp-quote sep) str))])
      (match (regexp-match px x)
        [(list _ k v) (f d k v)]
        [else #|(printf "ignoring ~s from ~s\n" x str)|# d])))

(define/contract (string->dict str sep eq-delim)
  (string? string? string? . -> . dict?)
  (k/v-string->dict str sep eq-delim #t
                    (lambda (d k v)
                      (dict-set d k (string->symbol v)))))

(define/contract (string+dict->dict str d sep eq-delim)
  (string? dict? string? string? . -> . dict?)
  (k/v-string->dict str sep eq-delim #f
                    (lambda (d2 k v)
                      (define new-k (dict-ref d k #f))
                      (cond [new-k (dict-set d2 new-k v)]
                            [else #|(printf "ignoring ~s, not in ~s ~v\n"
                                          k str d)|#
                                  d]))))

;; The values in dict are any/c; the ~a string is taken. When a value
;; is a procedure, it is called with dict d, and the ~a string of its
;; return value is used. This lets you supply e.g. something that
;; calculates Authorization header based on the other values.
(define/contract (dict+template->string d s)
  (dict? string? . -> . string?)
  ;; Handle only non-procedure values.
  (define (pass1 s)
    (for/fold ([s s])
              ([(k v) (in-dict d)])
      (cond [(procedure? v) s]
            [else
             (regexp-replace (regexp (regexp-quote (format "{~a}" k)))
                             s
                             (format "~a" v))])))
  ;; Handle only procedure values, now that we have a string filled in
  ;; with all non-procedure values. We can pass that string to the
  ;; procedure, as well as the dict. That request string may be useful
  ;; to e.g. a procedure that is calculating an authorization
  ;; signature.
  (define (pass2 s)
    (for/fold ([s s])
                   ([(k v) (in-dict d)])
      (cond [(procedure? v)
             (regexp-replace (regexp (regexp-quote (format "{~a}" k)))
                             s
                             (format "~a" (v d s)))]
            [else s])))
  (define (check s)
    (define xs (regexp-match* #rx"{(.+?)}" s))
    (cond [(empty? xs) s]
          [else (error 'dict+template->string
                       "template value(s) not filled in: ~a"
                       xs)]))
  (check (pass2 (pass1 s))))

(define/contract (string+api->dict s a)
  (string? api? . -> . dict?)
  ;; Use an alist instead of hash; few items
  (for/list ([k (api-path-syms a)]
             [v (cdr (or (regexp-match (api-path-px a) s)
                         '('n/a)))])
    (cons k v)))

;; Server: From an HTTP request that has already been matched with a
;; api?, fill a dict? with all of the parameterized values.
(define/contract (request->dict a s)
  (api? string? . -> . dict?)
  (define-values (method path query heads entity) (split-request s))
  (dict-merge
   (string+api->dict path a)
   (string+dict->dict query (api-query-dict a) "&" "=")
   (string+dict->dict heads (api-head-dict a) "\n" ":")
   (cond [(regexp-match?
           #px"Content-Type\\s*:\\s*application/x-www-form-urlencoded"
           heads)
          (string+dict->dict entity (api-form-dict a) "&" "=")]
         [else (hash)])))

;; Client: From a dict, construct a request string.
(define/contract (dict->request a d)
  (api? dict? . -> . string?)
  (dict+template->string d (api-req a)))

(define/contract (request-matches-api? a r)
  (api? string? . -> . boolean?)
  (regexp-match? (api-route-px a) r))

(define/contract (try-api? a f r)
  (api? (dict? . -> . dict?) string? . -> . (or/c #f string?))
  (cond [(request-matches-api? a r)
         (let* ([dict-req (request->dict a r)]
                [dict-resp (f dict-req)])
           (printf "=== Request matched ~s\nIN==> ~v\n<==OUT ~v\n"
                   (api-name a) dict-req dict-resp)
           (dict->response a dict-resp))]
        [else #f]))

(define/contract (dispatch r)
  (string? . -> . string?)
  (or (for/or ([(a f) (in-hash (apis))])
          (try-api? a f r))
      (404-response)))

(define (404-response)
  (string-join (list "HTTP/1.1 404 Not Found"
                     (format "Date: ~a" (seconds->gmt-string))
                     "")
               "\r\n"))

;; Server: Make response
(define (dict->response a d)
  (dict+template->string d (api-resp a)))

;; Client: From an HTTP response that has already been matched with a
;; api?, fill a dict? with all of the parameterized values.
(define/contract (response->dict a s)
  (api? string? . -> . dict?)
  (define-values (status heads entity) (split-response s))
  (dict-set* (string+dict->dict heads (api-resp-head-dict a) "\n" ":")
             'Status (match status
                       [(pregexp "^HTTP/1\\.\\d{1}\\s+(.+?)$" (list _ x)) x])
             'Entity entity))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; markdown

;; Return a string with documentation for the API, in markdown format.
(define/contract (api->markdown x)
  (api? . -> . string?)
  (string-append
   (header1 (api-name x))
   (api-desc x) "\n"
   "\n"
   (header2 "Request")
   (block-indent (api-req x)) "\n"
   "\n"
   (header2 "Response")
   (block-indent (api-resp x)) "\n"
   "\n"
   ))

(define (header s c)
  (string-append s "\n"
                 (make-string (string-length s) c) "\n"
                 "\n"))

(define (header1 s)
  (header s #\=))

(define (header2 s)
  (header s #\-))

(define (block-indent s)
  (string-append "    "
                 (string-join (regexp-split "\n" s)
                              "\n    ")))
                              
;; Return a string with documentation for the API, in Scribble format.
(define/contract (api->scribble x)
  (api? . -> . string?)
  "")                                   ;TO-DO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (curlies s)
  (map (lambda (x)
         (string->symbol (cadr (regexp-match #rx"^{(.+?)}$" x))))
       (regexp-match* #rx"{(.+?)}" s)))
  
(define/contract (api-inputs a)
  (api? . -> . (listof symbol?))
  (curlies (api-req a)))

(define (api-outputs a)
  (curlies (api-resp a)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define symbol->keyword (compose1 string->keyword symbol->string))
(define keyword->symbol (compose1 string->symbol keyword->string))

(define (make-api-dict-procedure a)
  (lambda (d)
    (dict->request a d)))

;; Instead of a function that takes a dict, a function that takes
;; keyword arguments.
(define (make-api-keyword-procedure a)
  (define f (make-keyword-procedure
             (lambda (kws vs . rest)
               (dict->request a
                              (map cons
                                   (map keyword->symbol kws)
                                   vs)))))
  (define kws (map string->keyword
                   (sort (map symbol->string
                              (api-inputs a))
                         string<?)))
  (procedure-reduce-keyword-arity f 0 kws kws))

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
;;
;; Markdown parsing
;;
;; Note: I suck at parsers. This is ad-hoc, fragile, bad at error-reporting.

;; Pregexp for one section of documentation:
(define px-api (pregexp (string-append "^"
                                       "# (.+?)\n+" ;name
                                       "(.+?)\n+"   ;desc
                                       "## (?i:Request):\\s*\n+"
                                       "(.+?)\n*"   ;req
                                       "## (?i:Response):\\s*\n+"
                                       "(.+?)\n*"   ;resp
                                       "$"
                                       )))

(define/contract (wffi-lib s)
  (path-string? . -> . (listof api?))
  (markdown->apis (file->string s)))

(define/contract (markdown->apis s)
  (string? . -> . (listof api?))
  (for/list ([x (in-list (get-sections s))])
    (apply init-api (get-subsections x))))

(define (get-sections s)
  (let loop ([xs (map car (regexp-match-positions* #rx"(?m:^# .+?\n)" s))])
    (cond
     [(empty? xs) (list)]
     [(empty? (cdr xs)) (cons (substring s (car xs)) (loop (cdr xs)))]
     [else (cons (substring s (car xs) (cadr xs)) (loop (cdr xs)))])))

(define (get-subsections s)
  (match s
    [(pregexp px-api (list _ name desc req resp))
     (list name desc (clean req) (clean resp))]
    [else #f]))

(define (kill-leading-spaces s)
  (string-join (for/list ([s (in-list (regexp-split "\n" s))])
                 (regexp-replace #px"^\\s+" s ""))
               "\n"))
(define (join-query-params s)
  (regexp-replace* "\n&" s "\\&"))

(define (ensure-double-newline s)
  (cond [(regexp-match? #px"\n{2}" s) s]
        [else (string-append s "\n")]))

(define clean
  (compose1 ensure-double-newline
            join-query-params
            kill-leading-spaces
            ))

(define/contract (get-wffi-obj lib name)
  ((listof api?) string? . -> . procedure?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (cond [a (make-api-dict-procedure a)]
        [else (error 'wffi-define "can't find ~s" name)]))

(define/contract (get-wffi-obj/kw lib name)
  ((listof api?) string? . -> . procedure?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (cond [a (make-api-keyword-procedure a)]
        [else (error 'wffi-define "can't find ~s" name)]))

;;(kill-leading-spaces "\n  adfasdf\n asdfasdfds")
;;(join-query-params "fooo\n&bar\n&foo")
;;(ensure-double-newline-ending "adsfadsf\n\nasdfasdf\n")

(define as (markdown->apis (file->string "example.md")))
;; (define f (make-api-keyword-procedure (first as)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Example using wffi-lib, get-wiff-obj, get-wifi-obj/kw
#|
(define lib (wffi-lib "example.md"))
(define get-example (get-wffi-obj lib "Example GET API"))
(define get-example/kw (get-wffi-obj/kw lib "Example GET API"))

(get-example (hash
              'user "greg"
              'item "12345"
              'a "A"
              'b "B" ;try comment this out to catch missing keyword
              ;;'UNDEFINED "UNDEFINED" ;try un-comment to catch undef kw
              'date (seconds->gmt-string)
              'endpoint "endpoint"
              'auth "auth"))

(get-example/kw #:user "greg"
                #:item "1"
                #:a "a"
                #:b "b" ;try comment this out to catch missing keyword
                ;;#:UNDEFINED "undefined" ;try un-comment to catch undef kw
                #:date (seconds->gmt-string)
                #:endpoint "endpoint"
                #:auth "auth")

(apply-dict get-example/kw
            (hash
             'user "greg"
             'item "12345"
             'a "A"
             'b "B" ;try comment this out to catch missing keyword
             ;;'UNDEFINED "UNDEFINED" ;try un-comment to catch undef kw
             'date (seconds->gmt-string)
             'endpoint "endpoint"
             'auth "auth"))
|#
