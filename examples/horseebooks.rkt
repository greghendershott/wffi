#lang racket

(require wffi/client)
(provide get)

(define lib (wffi-lib "horseebooks.md"))
(define _get (wffi-dict-proc lib "Get"))
(define (get paragraphs)
  (_get (hash 'paragraphs paragraphs)))

;; ;; Examples
;; (get 1)
;; (get 2)
