#lang racket

(require "key-value.rkt")

(provide (struct-out api)
         init-api
         (all-from-out "key-value.rkt"))

(struct api
        (name        ;string?
         desc        ;string?
         req         ;string?  Stored only for doc purposes
         resp        ;string?  Stored only for doc purposes
         route-px    ;pregexp?
         req-method  ;symbol?
         req-path    ;(listof (or/c string? variable?))
         req-query   ;(listof keyval?)
         req-head    ;(listof keyval?)
         resp-head   ;(listof keyval?)
        ) #:transparent)


(define/contract (init-api name desc req resp
                           req-method req-path req-query req-head resp-head)
  (string? string? string? string? symbol? (listof (or/c string? variable?))
           (listof keyval/c) (listof keyval/c) (listof keyval/c)
           . -> . api?)
  (api name desc req resp
       (route-px req-method req-path)
       req-method req-path req-query req-head resp-head))
     
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
                     [else (error 'init-api)]))
                 "")
    "\\s+")))
