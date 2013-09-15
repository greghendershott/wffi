#lang racket

(require wffi/client)
(provide (all-defined-out))

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

;; Example of a handy wrapper of a wrapper:
(define (image-upload/uri uri name)
  (image-upload 'image uri
                'type "url"
                'name name))

;; Show all
;; ;; (map api-func-name (api-funcs imgur-v3-lib))

;; Test
#|

(image-upload 'image "http://racket-lang.org/logo.png"
              'type "url"
              'name "Racket logo)"
(image-upload/uri "http://racket-lang.org/logo.png" "Racket logo")

;; Upload an image, get its "hash" and "deletehash" ID from the
;; response, pass hash to `image` to see the attributes, and pass
;; deletehash to `delete-hash` to delete it.
(let* ([js (image-upload/uri "http://racket-lang.org/logo.png" "Racket logo")]
       [id (dict-refs js 'data 'id)]
       [dh (dict-refs js 'data 'deletehash)])
  (displayln "Image uploaded. Get its attributes:")
  (pretty-print (image 'id id))
  ;; Note: Delete doesn't work in Imgur v3 API without OAuth
  (displayln "Deleting it:")
  (image-delete 'deletehash dh))

|#


