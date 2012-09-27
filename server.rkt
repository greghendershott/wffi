#lang racket

(require (planet gh/http)
         net/uri-codec
         "api.rkt"
         ;;"grammar.rkt"
         "markdown.rkt"
         "split.rkt"
         "dict-merge.rkt"
         )

(provide apis
         register-api!
         dispatch
         try-api?
         request-matches-api?
         )

;; From an HTTP request that has already been matched with an api?,
;; fill a dict? with all of the parameterized values.
(define/contract (request->dict a s)
  (api? string? . -> . dict?)
  (define-values (m p q h e) (split-request s))
  (match-define (api _ _ _ _ pt _ _ _) a)
  (dict-merge
   (for/hash ([v (regexp-split #rx"/" p)]
              [k pt] #:when (not (string? k)))
     (values (cadr k) v))
   (for/hash ([x (regexp-split #rx"&" q)] #:when (not (string=? "" x)))
     (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
               (values (string->symbol k) v)]))
   (for/hash ([x (regexp-split #rx"\r|\n|\r\n" h)])
     (match x [(pregexp "^(.+?)\\s*:\\s*(.+?)$" (list _ k v))
               (values (string->symbol k) v)]))
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

(define (dict->response a d)
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
  (match-define (api _ _ _ _ _ _ _ h) a)
  (define status (format "HTTP/~a ~a ~a"
                         (dict-ref d 'HTTP-Ver "1.0")
                         (dict-ref d 'HTTP-Code "200")
                         (dict-ref d 'HTTP-Text "OK")))
  (define head
    (string-append
     (string-join (filter values (for/list ([x h])
                                   (define kv (to-cons x))
                                   (cond [kv (format "~a: ~a" (car kv) (cdr kv))]
                                         [else #f])))
                  "\r\n")
     "\r\n"))
  ;; (define body (alist->form-urlencoded
  ;;               (for/list ([x b])
  ;;                 (match x
  ;;                   [(list k v) (cons k (format "~a" (dict-ref d k v)))]
  ;;                   [(var k) (cons k (format "~a" (dict-ref d x)))]))))
  (values status head #|body|#))


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
