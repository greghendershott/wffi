#lang racket

(require wffi/client
         json)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".last.fm-api-key")])
  (match (file->string file #:mode 'text)
    [(pregexp "^\\s*API Key\\s*=\\s*(.*?)\\s*\n+?" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr. Else raise an error.
(define (check-response who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200) (bytes->jsexpr (dict-ref d 'entity))]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define endpoint (make-parameter "http://ws.audioscrobbler.com"))
(define lib (wffi-lib "last.fm.md"))

(define-syntax-rule (defproc name api-name)
  (begin (define name (compose1 (lambda (x) (check-response #'name x))
                                (wffi-rest-proc lib api-name endpoint)))
         (provide name)))

(defproc chart "Chart")

;; Examples
#|
(chart 'api-key (api-key)
       'method "chart.getHypedArtists"
       'limit 1)

(chart 'api-key (api-key)
       'method "chart.getLovedTracks"
       'limit 1)
|#
