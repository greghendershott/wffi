#lang racket

(require wffi/client
         json)

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".imgur-api-key")])
  (match (file->string file #:mode 'text)
    [(regexp "^\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

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
                     
(define (add-common-parameters h)
  (hash-set* h
             'key (api-key)))

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

(define lib (wffi-lib "imgur.md"))

(define (chain . fs)
  (apply compose1 (reverse fs)))

(define-syntax-rule (defproc name api-name)
  (begin (define name (chain hash
                             add-common-parameters
                             (wffi-dict-proc lib api-name)
                             (lambda (x) (check-response (syntax-e #'name) x))))
         (provide name)))

(defproc stats "Stats")
(defproc upload "Upload")
(defproc album "Album")
(defproc image "Image")
(defproc delete-image "Delete Image")

(define (upload-uri uri name)
  (upload 'image uri
          'type "url"
          'name name))

;; Test
#|

(stats) 
(stats 'view "today")
(stats 'view "week")

(upload 'key (api-key) 'image "http://racket-lang.org/logo.png"
        'type "url" 'name "Racket logo")
(upload-uri "http://racket-lang.org/logo.png" "Racket logo")

(album 'hash 2)
(image 'hash 2)

;; Upload an image, get its "hash" and "deletehash" ID from the
;; response, pass hash to `image` to see the attributes, and pass
;; deletehash to `delete-hash` to delete it.
(let* ([js (upload-uri "http://racket-lang.org/logo.png" "Racket logo")]
       [h (dict-refs js 'upload 'image 'hash)]
       [dh (dict-refs js 'upload 'image 'deletehash)])
  (displayln "Image uploaded. Get its attributes:")
  (pretty-print (image 'hash h))
  (displayln "Deleting it:")
  (delete-image 'deletehash dh))

|#


