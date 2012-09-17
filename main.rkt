#lang racket

(require (planet gh/http/request)
         rackunit
         "dict-merge.rkt"
         )
         
(provide defapi
         dict->request
         request->dict
         dict->response
         response->dict
         dispatch?
         )

(struct api
        (proc            ;(dict? . -> . dict?)
         name            ;string?
         desc            ;string?
         req             ;string?
         resp            ;string?
         route-px        ;pregexp?
         path-px         ;pregexp?
         path-syms       ;(listof symbol?)
         query-dict      ;(dict string? symbol?)
         heads-dict      ;(dict string? symbol?)
         form-dict       ;(dict string? symbol?)
         resp-heads-dict ;(dict string? symbol)
        ) #:transparent)

(define hapi (make-hash)) ;route pregexp? -> api?
(define (register-api! a)
  (hash-set! hapi (api-route-px a) a))
             
(define-syntax-rule (defapi name title [desc ...] [req ...] [resp ...]
                      body0 body ...)
  (begin
    (define name (init-api (lambda (d) body0 body ...)
                           `title
                           (multi-line `(desc ...))
                           (multi-line `(req ...))
                           (multi-line `(resp ...))))
    (register-api! name)))

(define (multi-line xs)
  (string-append (string-join xs "\n") "\n"))

(define/contract (init-api proc name doc req resp)
  ((dict? . -> . dict?) string? string? string? string?  . -> . api?)
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
  (define heads-dict (string->dict heads "\n" ":"))
  (define form-dict (string->dict entity "&" "="))
  (define-values (resp-heads resp-entity) (split-response resp))
  (define resp-heads-dict (string->dict resp-heads "\n" ":"))
  (api proc
       name
       doc
       req
       resp
       route-px
       (pregexp path-re)
       path-syms
       query-dict
       heads-dict
       form-dict
       resp-heads-dict
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
         [else (error 'init-api "can't determine path and query")]))
     ;; I couldn't figure out the regexp to split h and e in the
     ;; first place, so split them now.
     (define-values (h e)
       (match (regexp-split "\n\n" h+e)
         [(list h e) (values h e)]
         [(list h) (values h "")]
         [(list) (values "" "")]
         [else (error 'init-api "can't determine heads and entity")]))
     (values m p q h e)]
    [else (error 'init-api "can't parse request template")]))  

(define/contract (split-response req)
  (string? . -> . (values string? string?))
  (match (regexp-split "\n\n" req)
    [(list h e) (values h e)]
    [(list h) (values h "")]
    [(list) (values "" "")]
    [else (error 'split-response "can't determine heads and entity")]))

(define/contract (k/v-string->dict str sep eq-delim curly-val? f)
  (string? string? string? boolean? (dict? string? string? . -> . dict?)
           . -> . dict?)
  (define px (pregexp (string-append "^(\\S+?)\\s*"
                                     (regexp-quote eq-delim)
                                     "\\s*"
                                     (if curly-val? "\\{" "")
                                     "(.+?)" ;;"(\\S+?)"
                                     (if curly-val? "\\}" "")
                                     "$")))
  (for/fold ([d (hash)])
            ([x (in-list (regexp-split (regexp-quote sep) str))])
      (match (regexp-match px x)
        [(list _ k v) (f d k v)]
        [else d])))

(define/contract (string->dict str sep eq-delim)
  (string? string? string? . -> . dict?)
  (k/v-string->dict str sep eq-delim #t
                    (lambda (d k v)
                      (dict-set d k (string->symbol v)))))

(define/contract (string+dict->dict str d sep eq-delim)
  (string? dict? string? string? . -> . dict?)
  (printf "string+dict->dict str=~s d=~v\n" str d)
  (k/v-string->dict str sep eq-delim #f
                    (lambda (d2 k v)
                      (define new-k (dict-ref d k #f))
                      (cond [new-k (dict-set d2 new-k v)]
                            [else (printf "~s not found in ~v\n" k d) d]))))

(define/contract (dict+template->string d s)
  (dict? string? . -> . string?)
  (define (check s)
    (define xs (regexp-match* #rx"{(.+?)}" s))
    (cond [(empty? xs) s]
          [else (error 'dict+template->string
                       "template value(s) not filled in: ~a"
                       xs)]))
  (check (for/fold ([s s])
             ([(k v) (in-dict d)])
           ;;(printf "k=~a v=~a\n" k v)
           (regexp-replace (regexp (regexp-quote (format "{~a}" k)))
                           s
                           (format "~a" v)))))

(define (string+api->dict s a)
  (for/hash ([k (api-path-syms a)]
             [v (cdr (or (regexp-match (api-path-px a) s)
                         '('n/a)))])
    (values k v)))

;; Server: From an HTTP request that has already been matched with a
;; api?, fill a dict? with all of the parameterized values.
(define/contract (request->dict a s)
  (api? string? . -> . dict?)
  (define-values (method path query heads entity) (split-request s))
  (dict-merge
   (string+api->dict path a)
   (string+dict->dict query (api-query-dict a) "&" "=")
   (string+dict->dict heads (api-heads-dict a) "\n" ":")
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

(define/contract (try-api? a r)
  (api? string? . -> . (or/c #f string?))
  (cond [(request-matches-api? a r)
         (let* ([proc (api-proc a)]
                [dict-req (request->dict a r)]
                [dict-resp (proc dict-req)])
           (printf "=== Request matched ~s\nIN==> ~v\n<==OUT ~v\n"
                   (api-name a) dict-req dict-resp)
           (dict->response a dict-resp))]
        [else #f]))

(define/contract (dispatch? r)
  (string? . -> . (or/c #f string?))
  (or (for/or ([a (in-list (hash-values hapi))])
          (try-api? a r))
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
  (define-values (heads entity) (split-response s))
  (dict-set* (string+dict->dict heads (api-resp-heads-dict a) "\n" ":")
             'Status (match heads
                       [(pregexp "^HTTP/1\\.\\d{1}\\s+(.+?)\n" (list _ x)) x])
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

(define/contract (api-inputs a)
  (api? . -> . (listof symbol?))
  (append (api-path-syms a)
          (hash-values (api-query-dict a))
          (hash-values (api-heads-dict a))
          (hash-values (api-form-dict a))))

(define (api-outputs a)
  (map (lambda (x)
         (string->symbol (cadr (regexp-match #rx"^{(.+?)}$" x))))
       (regexp-match* #rx"{(.+?)}" (api-resp a))))
