#lang racket

(require wffi/client
         json)

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr. Else raise an error.
(define (check-response who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200) (bytes->jsexpr (dict-ref d 'entity))]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))

(define (add-common-parameters h)
  (hash-set* h))

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

(define lib (wffi-lib "app.net.md"))

(define (chain . fs)
  (apply compose1 (reverse fs)))

(define-syntax-rule (defproc name api-name)
  (begin (define name (chain hash
                             add-common-parameters
                             (wffi-dict-proc lib api-name)
                             (lambda (x) (check-response (syntax-e #'name) x))))
         (provide name)))

(defproc user-posts "User posts")
(defproc post "Post")
(defproc global-stream "Global stream")
(defproc tagged-posts "Tagged posts")

;;(user-posts 'user-id "greghendershott")

;;(global-stream 'count 1)
;;(length (global-stream 'count 200))
