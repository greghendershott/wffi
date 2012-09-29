#lang racket

(require wffi/client)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".google-api-key")])
  (match (file->string file #:mode 'text)
    [(regexp "^\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define endpoint (make-parameter "https://www.googleapis.com"))
(define lib (wffi-lib "google-plus.md"))
(define get-person (wffi-rest-proc lib "Get person" endpoint))

(get-person 'key (api-key)
            'userId "107023078912536369392")
