#lang racket

(require wffi/client
         json)

(define (read-client-id [file (build-path (find-system-path 'home-dir)
                                          ".imgur-api-client")])
  (for/or ([s (file->lines file #:mode 'text)])
    (match s
      [(regexp "^\\s*(?i:ClientID)\\s*=\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
      [else #f])))
(define client-id (make-parameter (read-client-id)))

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
             'Authorization (format "Client-ID ~a" (client-id))))

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

(define lib (wffi-lib "imgur.v3.md"))

(define (chain . fs)
  (apply compose1 (reverse fs)))

(define-syntax-rule (defproc name api-name)
  (begin (define name (chain hash
                             add-common-parameters
                             (wffi-dict-proc lib api-name)
                             (lambda (x) (check-response (syntax-e #'name) x))))
         (provide name)))

(defproc image-info "Image")
(defproc image-delete "Image Deletion")
(defproc image-upload "Image Upload")
(defproc image-update-info "Update Image Information")

(define (image-upload/uri uri name)
  (image-upload 'image uri
                'type "url"
                'name name))

;; Test
#|

(image-upload 'image "http://racket-lang.org/logo.png"
              'type "url"
              'name "Racket logo")
(image-upload/uri "http://racket-lang.org/logo.png" "Racket logo")

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


