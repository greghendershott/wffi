#lang racket

(require wffi/client)

(define (add-common-parameters h)
  (hash-set* h))

(wffi-define-all "app.net.md" add-common-parameters check-response/json)

;;(user-posts 'user-id "greghendershott")

;;(global-stream 'count 1)
;;(length (global-stream 'count 200))
