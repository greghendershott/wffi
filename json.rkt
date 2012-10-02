#lang racket

(require json
         "api.rkt")

(define/contract (api->jsexpr a)
  (api? . -> . jsexpr?)
  (define (->js x)
    (match x
      [(optional x) (hasheq 'optional (->js x))]
      [(keyval k v) (hasheq k (->js v))]
      [(constant x) (hasheq 'constant x)]
      [(variable x) (hasheq 'variable (symbol->string x))]
      [else x]))

  (match-define (api name desc _ _ _ method path query head resp-head) a)
  (hasheq 'name name
          'desc desc
          'request-method (symbol->string method)
          'request-path (map ->js path)
          'request-query (map ->js query)
          'request-head (map ->js head)
          'response-head (map ->js resp-head)))
           
(define/contract (jsexpr->api j)
  (jsexpr? . -> . api?)
  (define (->a x)
    (match x
      [(? string? x) x]
      [(hash-table ('optional x)) (optional (->a x))]
      [(hash-table ('constant x)) (constant x)]
      [(hash-table ('variable x)) (variable (string->symbol x))]
      [(hash-table (k v)) (keyval k (->a v))]))

  (init-api (hash-ref j 'name)
            (hash-ref j 'desc)
            ""
            ""
            (string->symbol (hash-ref j 'request-method))
            (map ->a (hash-ref j 'request-path))
            (map ->a (hash-ref j 'request-query))
            (map ->a (hash-ref j 'request-head))
            (map ->a (hash-ref j 'response-head))
            ))

(module+ test
  (require rackunit
           "markdown.rkt")
  (let ()
    (define before (wffi-obj (wffi-lib "example.md") "Example GET API"))
    (define js (api->jsexpr before))
    (define after (jsexpr->api js))
    (check-equal? before after)))
