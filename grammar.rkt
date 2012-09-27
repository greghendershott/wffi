#lang racket

(require "api.rkt")

(provide api-grammar->api-struct
         api-grammar?
         api-parts
         request?
         request-parts
         response?
         response-parts
         method?
         path?
         query?
         head?
         body?
         status?
         )

;; Perhaps parse the markdown text into this intermediate
;; respresentation of the grammar?

#|

<api>      ::= (<name> <doc> <request> <response>)

<name>     ::= string?
<doc>      ::= string?

<request>  ::= (<method> (<path>) (<query>) (<head>) (<body>))
<response> ::= (<status> <head> <body>)

<method>   ::= 'head | 'get | 'put | 'post | 'delete

<path>     ::= string?
            |  symbol?

<query>    ::= <map>
<head>     ::= <map>
<body>     ::= <map>
<status>   ::= <map>

<map>      ::= symbol?
            |  (symbol? any/c)    ;; Default value

|#

(define (api-grammar->api-struct g)
  (define-values (name doc request response) (api-parts g))
  (define-values (method path query head body) (request-parts request))
  (define route-px
    (pregexp
     (string-append
      "^"
      "(?i:" (regexp-quote (symbol->string method)) ")"
      "\\s+"
      (string-join (for/list ([x path])
                     (cond [(string? x) (regexp-quote x)]
                           [(symbol? x) "(.+?)"]
                           [else (error 'api-grammar->api-struct)]))
                   "")
      "\\s+")))
  (api name doc request response route-px))

(define (api-grammar? x)
  (with-handlers ([exn:fail? (lambda _ #f)])
    (api-parts x)
    #t))

(define (api-parts x)
  (match x
    [(list (? name? name) (? doc? doc)
           (? request? request) (? response? response))
     (values name doc request response)]
    [else (error 'api-parts "bad grammar ~v" x)]))
  
(define (name? x)
  (or (string? x)
      (begin "expected string? for `name`, got ~v" x)))

(define (doc? x)
  (or (string? x)
      (begin "expected string? for `doc`, got ~v" x)))

(define (request? x)
  (with-handlers ([exn:fail? (lambda _ #f)])
    (request-parts x)
    #t))

(define (request-parts x)
  (match x
    [(list (? method? method) (? path? path) (? query? query)
           (? head? head) (? body? body))
     (values method path query head body)]
    [else (error 'request-method "not a request ~v\n" x)]))
  
(define (response? x)
  (with-handlers ([exn:fail? (lambda _ #f)])
    (response-parts x)
    #t))

(define (response-parts x)
  (match x
    [(list (? status? status) (? head? head) (? body? body))
     (values status head body)]
    [else (error 'response-parts "not a response ~v" x)]))

(define (method? x)
  (or (for/or ([y '(head get put post delete)])
        (equal? x y))
      (begin (printf "not a method? ~v\n" x) #f)))

(define (path? xs)
  (and (list? xs)
       (for/and ([x xs])
         (or (string? x)
             (symbol? x)
             (begin (printf "not a path? ~v\n" xs) #f)))))

(define (query? x) (map? x))
(define (head? x) (map? x))
(define (body? x) (map? x))
(define (status? x) (map? x))

(define (map? xs)
  (and (list? xs)
       (for/and ([x xs])
         (match x
           [(list (? symbol?) _) #t]
           [(? symbol?) #t]
           [else (printf "not a map? ~v\n" x)
                 #f]))))


;; Examples

(api-grammar->api-struct
 '("Create Domain"
   "doc string"
   (post ("https://sdb.amazonaws.com/")
         ([Action "CreateDomain"]
          AWSAccessKeyId
          DomainName
          [SignatureVersion 2]
          [SignatureMethod "HmacSHA256"]
          Timestamp
          [Version "2009-04-15"]
          Signature)
         ()
         ())
   (() () ())))

(api-grammar->api-struct
 '("Example GET API"
   "doc string"
   (get ("/user/" user "/items/" item)
        ()
        (Host Authorization)
        ())
   (() () (a b))))

(api-grammar->api-struct
 '("Example POST API"
   "doc string"
   (post ("/user/" user "/items/")
         ()
         (Host
          Authorization
          [Content-Type "application/x-www-form-urlencoded"]
          Content-Length)
         (a b))
   (() () ())))
