#lang racket

(require (planet gh/http)
         net/uri-codec
         "api.rkt"
         "markdown.rkt"
         "split.rkt"
         "dict-merge.rkt")

(provide current-api-funcs
         register-api-func!
         dispatch
         try-api-func?
         request-matches-api-func?
         wffi-lib
         wffi-obj
         api-func->markdown
         (struct-out api)
         (struct-out api-func))

;; From an HTTP request that has already been matched with an api-func?,
;; fill a dict? with all of the parameterized values.
(define/contract (request->dict a s)
  (api-func? string? . -> . dict?)
  (define-values (m p q h e) (split-request s))
  (define pt (api-func-req-path a))
  (displayln pt)
  (dict-merge
   (for/hash ([v (regexp-split #rx"/" p)]
              [k pt] #:when (variable? k))
     (values (variable-name k) v))
   (form-urlencoded->alist q)
   (heads-string->dict h)
   (cond [(regexp-match?
           #px"Content-Type\\s*:\\s*application/x-www-form-urlencoded"
           h)
          (for/hash ([x (regexp-split #rx"&" e)] #:when (not (string=? "" x)))
            (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
                      (values (string->symbol k) v)]))]
         [else (hash)])))

#;
(define ex (wffi-obj (wffi-lib "example.md") "Example POST API"))

#;
(request->dict ex
               #<<--
POST /user/greg/items/21?qa=qa&qb=qb HTTP/1.1
Host: my.host.com
Authorization: MyFakeAuthorization
Content-Type: application/x-www-form-urlencoded
Content-Length: 7

a=1&b=2
--
)

(define/contract (dict->response a d)
  (api-func? dict? . -> . (values string? dict? (or/c #f bytes?)))
  (define (to-cons x)
    (match x
      [(keyval k (constant v)) (cons k v)]
      [(keyval k (variable v)) (cons k (format "~a" (dict-ref d v)))]
      [(optional (keyval k (list 'VARIABLE v)))
       (cond [(dict-has-key? d v) (cons k (format "~a" (dict-ref d v)))]
             [else #f])]
      [(optional (keyval k (list 'CONSTANT v)))
       (cond [(dict-has-key? d k) (cons k (format "~a" (dict-ref d k)))]
             [else (cons k v)])]
      [else (error 'dict->request "~v" x)]))
  (define h (api-func-resp-head a))
  (displayln h)
  (define status (format "HTTP/~a ~a ~a"
                         (dict-ref d 'HTTP-Ver "1.0")
                         (dict-ref d 'HTTP-Code "200")
                         (dict-ref d 'HTTP-Text "OK")))
  (define heads (filter-map to-cons h))
  ;; (define body (alist->form-urlencoded (filter-map to-cons b)))
  (values status heads #f))

#;
(dict->response ex (hash 'Date (seconds->gmt-string)
                         'Content-Type "text/plain"
                         'Content-Length 10))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dispatch

(define current-api-funcs (make-parameter (make-hash)))
                                        ;hashof api-func? => (dict? -> dict?)
(define (register-api-func! a proc)
  (hash-set! (current-api-funcs) a proc))

(define/contract (request-matches-api-func? a r)
  (api-func? string? . -> . boolean?)
  (regexp-match? (api-func-route-px a) r))

(define/contract (try-api-func? a f r)
  (api-func? (dict? . -> . dict?) string? . -> . (or/c #f string?))
  (cond [(request-matches-api-func? a r)
         (let* ([dict-req (request->dict a r)]
                [dict-resp (f dict-req)])
           (log-debug (format "=== Request matched ~s\nIN==> ~v\n<==OUT ~v"
                              (api-func-name a) dict-req dict-resp))
           (define-values (s h e) (dict->response a dict-resp))
           (string-append s "\r\n"
                          (string-join (map (lambda (x)
                                              (format "~a: ~a" (car x) (cdr x)))
                                            h)
                                       "\r\n")
                          "\r\n\r\n"))]
        [else #f]))

(define/contract (dispatch r)
  (string? . -> . string?)
  (or (for/or ([(a f) (in-hash (current-api-funcs))])
          (try-api-func? a f r))
      (404-response)))

(define (404-response)
  (string-join (list "HTTP/1.1 404 Not Found"
                     (format "Date: ~a" (seconds->gmt-string))
                     "")
               "\r\n"))
