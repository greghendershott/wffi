#lang racket

(require json
         "api.rkt")

(provide api-func->jsexpr
         jsexpr->api-func)

(define/contract (api-func->jsexpr a)
  (api-func? . -> . jsexpr?)
  (define (->js x)
    (match x
      [(optional x) (hasheq 'optional (->js x))]
      [(keyval k v) (hasheq k (->js v))]
      [(constant x) (hasheq 'constant x)]
      [(variable x) (hasheq 'variable (symbol->string x))]
      [else x]))
  (match-define (api-func name docs _ method path query head resp-head) a)
  (hasheq 'name name
          'docs docs
          'request-method (symbol->string method)
          'request-path (map ->js path)
          'request-query (map ->js query)
          'request-head (map ->js head)
          'response-head (map ->js resp-head)))
           
(define/contract (jsexpr->api-func j)
  (jsexpr? . -> . api-func?)
  (define (->a x)
    (match x
      [(? string? x) x]
      [(hash-table ('optional x)) (optional (->a x))]
      [(hash-table ('constant x)) (constant x)]
      [(hash-table ('variable x)) (variable (string->symbol x))]
      [(hash-table (k v)) (keyval k (->a v))]))
  (init-api-func (hash-ref j 'name)
                 (hash-ref j 'docs)
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
    (define before (wffi-obj (wffi-lib "examples/imgur.md") "Stats"))
    (define js (api-func->jsexpr before))
    (define after (jsexpr->api-func js))
    (check-equal? before after)))
