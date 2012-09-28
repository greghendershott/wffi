#lang racket

(require "api.rkt"
         "markdown.rkt")

(provide wffi-lib
         wffi-obj)

(define/contract (wffi-lib s)
  (path-string? . -> . (listof api?))
  (markdown->apis (file->string s)))

(define/contract (wffi-obj lib name)
  ((listof api?) string? . -> . api?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (cond [a a]
        [else (error 'wffi-obj "can't find ~s" name)]))

