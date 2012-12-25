#lang racket

(require wffi/client)

(define (read-client-id [file (build-path (find-system-path 'home-dir)
                                          ".imgur-api-client")])
  (for/or ([s (file->lines file #:mode 'text)])
    (match s
      [(regexp "^\\s*(?i:ClientID)\\s*=\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
      [else #f])))
(define client-id (make-parameter (read-client-id)))

(define (add-common-parameters h)
  (hash-set* h
             'Authorization (format "Client-ID ~a" (client-id))))

(wffi-define-all "imgur.v3.md" add-common-parameters check-response/json)

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


