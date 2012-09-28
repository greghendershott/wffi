#lang racket

(require wffi
         wffi/client
         json)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".imgur-api-key")])
  (match (file->string file #:mode 'text)
    [(regexp "^\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr. Else raise an error.
(define (check-response who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200)
         (cond [(equal? "application/json" (dict-ref d 'Content-Type))
                (bytes->jsexpr (dict-ref d 'entity))]
               [else (dict-ref d 'entity)])]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))
                     
;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define endpoint (make-parameter "https://api.imgur.com"))
(define lib (wffi-lib "imgur.md"))

(define stats (compose1 (lambda (x) (check-response 'stats x))
                        (wffi-kwd-proc lib "Stats" endpoint)))

(define upload (compose1 (lambda (x) (check-response 'upload x))
                         (wffi-kwd-proc lib "Upload" endpoint)))

(define album (compose1 (lambda (x) (check-response 'album x))
                        (wffi-kwd-proc lib "Album" endpoint)))

(define image (compose1 (lambda (x) (check-response 'image x))
                        (wffi-kwd-proc lib "Image" endpoint)))

(define delete (compose1 (lambda (x) (check-response 'delete x))
                         (wffi-kwd-proc lib "Delete Image" endpoint)))


(define (upload-uri uri name)
  (upload #:key (api-key)
          #:image uri
          #:type "url"
          #:name name))

;; Test
;; (stats) 
;; (stats #:view "today")
;; (upload #:key (api-key) #:image "http://racket-lang.org/logo.png"
;;         #:type "url" #:name "Racket logo")
;; (upload-uri "http://racket-lang.org/logo.png" "Racket logo")
;; (album #:hash 2)
;; (image #:hash 2)

;; This isn't working. Getting 400 Bad Request:
;; (delete #:hash "oWuf6")
