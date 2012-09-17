#lang racket

(provide dict-merge)

(define/contract (dict-merge . ds)
  (() #:rest (listof dict?) . ->* . dict?)
  (match ds
    [(list d0 ds ...)
     (for/fold ([d0 d0])
               ([d (in-list ds)])
       (for/fold ([d0 d0])
                 ([(k v) (in-dict d)])
         (dict-set d0 k v)))]
    [(list d) d]
    [(list) (hash)]))

(module+ test
  (require rackunit)
  (check-equal? (dict-merge (hash 1 1 2 2 3 3)
                            (hash 4 4 5 5 6 6))
                (hash 1 1 2 2 3 3 4 4 5 5 6 6))
  (check-equal? (dict-merge (hash 1 1 2 2 3 3 ))
                (hash 1 1 2 2 3 3))
  (check-equal? (dict-merge (hash))
                (hash)))
