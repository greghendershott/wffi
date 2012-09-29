#lang racket

(require "split.rkt"
         )

(provide (struct-out api)
         init-api)

(struct api
        (name        ;string?
         desc        ;string?
         route-px    ;pregexp?
         req         ;string?  Stored only for doc purposes
         resp        ;string?  Stored only for doc purposes
         req-method  ;list? parsed
         req-path    ;list? parsed
         req-query   ;list? parsed
         req-head    ;list? parsed
         resp-head   ;list? parsed
        ) #:transparent)


(define (init-api name desc req resp
                  req-method req-path req-query req-head resp-head)
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
                     [(list 'VARIABLE k) "(.+?)"]
                     [(? string? x) (regexp-quote x)]
                     [else (error 'init-api)]))
                 "")
    "\\s+")))
