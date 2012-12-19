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
  (dict-merge
   ;; path
   (for/hash ([v (regexp-split #rx"/" p)]
              [k (api-func-req-path a)] #:when (variable? k))
     (values (variable-name k) v))
   ;; query parameters
   (form-urlencoded->alist q)
   ;; headers
   (heads-string->dict h)
   ;; body (if application/x-www-form-urlencoded)
   (cond [(regexp-match?
           #px"Content-Type\\s*:\\s*application/x-www-form-urlencoded"
           h)
          (for/hash ([x (regexp-split #rx"&" e)] #:when (not (string=? "" x)))
            (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
                      (values (string->symbol k) v)]))]
         [else (hash)])))

#;
(define ex (wffi-obj (wffi-lib "examples/server-example.md") "Create user"))

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
  (api-func? dict? . -> . (values string? dict? (or/c bytes? (-> bytes?))))
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
  (define status (format "HTTP/~a ~a ~a"
                         (dict-ref d 'HTTP-Ver "1.0")
                         (dict-ref d 'HTTP-Code "200")
                         (dict-ref d 'HTTP-Text "OK")))
  (define heads (filter-map to-cons (api-func-resp-head a)))
  (define entity (dict-ref d 'Entity #""))
  (values status heads entity))

#;
(dict->response ex (hash 'Date (seconds->gmt-string)
                         'Content-Type "text/plain"
                         'Content-Length 10
                         'Entity #"I am the entity"
                         ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dispatch

;;hashof pregexp? => (cons api-func? (dict? -> dict?))
(define current-api-funcs (make-parameter (make-hash)))

(define (register-api-func! a proc)
  (hash-set! (current-api-funcs)
             (route-px (api-func-req-method a) (api-func-req-path a))
             (cons a proc)))

(define/contract (try-api-func? px a&f r)
  (pregexp? (cons/c api-func? (dict? . -> . dict?)) string?
            . -> . (or/c #f string?))
  (cond [(regexp-match? px r)
         (match-define (cons a f) a&f)
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
  (or (for/or ([(px a&f) (in-hash (current-api-funcs))])
          (try-api-func? px a&f r))
      (404-response)))

(define (404-response)
  (string-join (list "HTTP/1.1 404 Not Found"
                     (format "Date: ~a" (seconds->gmt-string))
                     "")
               "\r\n"))

(define (route-px req-method req-path)
  (pregexp
   (string-append
    "^"
    "(?i:" (regexp-quote (symbol->string req-method)) ")"
    "\\s+"
    (string-join (for/list ([x req-path])
                   (match x
                     [(variable k) "(.+?)"]
                     [(? string? x) (regexp-quote x)]
                     [else (error 'init-api-func)]))
                 "")
    "\\s+")))
