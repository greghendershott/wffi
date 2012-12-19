#lang racket

(require "key-value.rkt")

(provide (struct-out api)
         (struct-out api-func)
         (all-from-out "key-value.rkt"))

(struct api
        (endpoint   ;URI string?
         funcs      ;(listof api-func?)
         ) #:transparent)

(struct api-func
        (name        ;string?
         desc        ;string?
         req-method  ;symbol?
         req-path    ;(listof (or/c string? variable?))
         req-query   ;(listof keyval?)
         req-head    ;(listof keyval?)
         resp-head   ;(listof keyval?)
        ) #:transparent)
