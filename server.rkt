#lang racket

(require (planet gh/http)
         net/uri-codec
         "api.rkt"
         "markdown.rkt"
         "split.rkt"
         "dict-merge.rkt")

(provide apis
         register-api!
         dispatch
         try-api?
         request-matches-api?
         wffi-lib
         wffi-obj
         api->markdown
         (struct-out api))

;; From an HTTP request that has already been matched with an api?,
;; fill a dict? with all of the parameterized values.
(define/contract (request->dict a s)
  (api? string? . -> . dict?)
  (define-values (m p q h e) (split-request s))
  (define pt (api-req-path a))
  (dict-merge
   (for/hash ([v (regexp-split #rx"/" p)]
              [k pt] #:when (not (string? k)))
     (values (cadr k) v))
   (form-urlencoded->alist q)
   ;; (for/hash ([x (regexp-split #rx"&" q)] #:when (not (string=? "" x)))
   ;;   (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
   ;;             (values (string->symbol k) v)]))
   (heads-string->dict h)
   (cond [(regexp-match?
           #px"Content-Type\\s*:\\s*application/x-www-form-urlencoded"
           h)
          (for/hash ([x (regexp-split #rx"&" e)] #:when (not (string=? "" x)))
            (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
                      (values (string->symbol k) v)]))]
         [else (hash)])))

(define ex (first (markdown->apis (file->string "example.md"))))

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
  (api? dict? . -> . (values string? dict? (or/c #f bytes?)))
  (define (to-cons x)
    (match x
      [(list k (list 'CONSTANT v)) (cons k v)]
      [(list k (list 'VARIABLE v)) (cons k (format "~a" (dict-ref d v)))]
      [(list 'OPTIONAL (list k (list 'VARIABLE v)))
       (cond [(dict-has-key? d v) (cons k (format "~a" (dict-ref d v)))]
             [else #f])]
      [(list 'OPTIONAL (list k (list 'CONSTANT v)))
       (cond [(dict-has-key? d k) (cons k (format "~a" (dict-ref d k)))]
             [else (cons k v)])]
      [else (error 'dict->request "~v" x)]))
  (define h (api-resp-head a))
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

(define apis (make-parameter (make-hash))) ;hashof api? => (dict? -> dict?)
(define (register-api! a proc)
  (hash-set! (apis) a proc))

(define/contract (request-matches-api? a r)
  (api? string? . -> . boolean?)
  (regexp-match? (api-route-px a) r))

(define/contract (try-api? a f r)
  (api? (dict? . -> . dict?) string? . -> . (or/c #f string?))
  (cond [(request-matches-api? a r)
         (let* ([dict-req (request->dict a r)]
                [dict-resp (f dict-req)])
           (log-debug (format "=== Request matched ~s\nIN==> ~v\n<==OUT ~v"
                              (api-name a) dict-req dict-resp))
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
  (or (for/or ([(a f) (in-hash (apis))])
          (try-api? a f r))
      (404-response)))

(define (404-response)
  (string-join (list "HTTP/1.1 404 Not Found"
                     (format "Date: ~a" (seconds->gmt-string))
                     "")
               "\r\n"))
