#lang racket

(provide (struct-out value)
         (struct-out variable)
         (struct-out constant)
         (struct-out optional)
         (struct-out keyval)
         keyval/c)

;; A  variable IS A (kind of) value.
;; A  constant IS A (kind of) value.
;; An optional IS A (kind of) value that HAS A variable or constant value.

(struct value () #:transparent)
(struct variable value (name) #:transparent) ;name: symbol?
(struct constant value (v)    #:transparent) ;v: any/c
(struct optional value (x)    #:transparent) ;v: or/c variable? constant?

(struct keyval (k v) #:transparent)  ;k: symbol?, v: value?

(define keyval/c (or/c keyval? optional?))
