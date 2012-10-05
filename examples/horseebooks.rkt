#lang racket

(require wffi/client)
(provide get)

(define endpoint (make-parameter "http://horseebooksipsum.com"))
(define lib (wffi-lib "horseebooks.md"))
(define _get (wffi-dict-proc lib "Get" endpoint))
(define (get paragraphs)
  (_get (hash 'paragraphs paragraphs)))

;; ;; Examples
;; (get 1)
;; (get 2)
