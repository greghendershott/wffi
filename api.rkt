#lang racket

(require "split.rkt"
         )

(provide (struct-out api)
         init-api)

(struct api
        (name
         desc
         route-px
         req-method
         req-path
         req-query
         req-head
         resp-head
        ) #:transparent)


(define (init-api name desc req-method req-path req-query req-head resp-head)
  (define route-px
    (pregexp
     (string-append
      "^"
      "(?i:" (regexp-quote (symbol->string req-method)) ")"
      "\\s+"
      (string-join (for/list ([x req-path])
                     (match x
                       [(list 'VARIABLE k) "(.+?)"]
                       [(? string? x) (regexp-quote x)]
                       [else (error 'init-api)]))
                   "")
      "\\s+")))
  (api name desc route-px req-method req-path req-query req-head resp-head))

     
