#lang racket

(require wffi/server)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; For testing, some requests

(define example-get-request
#<<--
GET /user/greg/items/21?a=a&b=b HTTP/1.1
Host: my.host.com
Authorization: MyFakeAuthorization
Content-Length: 100
--
)

(define example-get-request-CRLF
  (string-join
   (list
    "GET /user/greg/items/21?a=a&b=b HTTP/1.1"
    "Host: my.host.com"
    "Authorization: MyFakeAuthorization"
    "Content-Length: 100")
   "\r\n"))

(define example-get-response
#<<--
HTTP/1.1 200 OK
Date: asdfasdfadf
Content-Type: text/plain
Content-Length: 5

abcde
--
)

(define example-post-request
#<<--
POST /user/greg/items/21 HTTP/1.1
Host: my.host.com
Authorization: MyFakeAuthorization
Content-Type: application/x-www-form-urlencoded
Content-Length: 7

a=1&b=2
--
)

(define upload-archive-request
#<<--
POST /12345/vaults/test/archives HTTP/1.1
Host: glacier.us-east1.amazonaws.com
x-amz-glacier-version: 2012-06-01
Date: 2012-08-01
Authorization: adsfasdfadsf
x-amz-archive-description: lipsum oreum
x-amz-sha256-tree-hash: adsfadsfasdfadf
x-amz-content-sha256: asdfasdfasdfadsf
Content-Length: 2000

asdfkjasdflkjasdfa
asdfasdfasdf
--
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Use the api to receive requests as a server and dispatch them.

(require (planet gh/http))
(define lib (wffi-lib "server-example.md"))
(register-api-func! (wffi-obj lib "Get user")
                    (lambda (d)
                      (hash 'Status "200 OK"
                            'Date (seconds->gmt-string)
                            'type "text/plain"
                            'Content-Length 0
                            'Content-Type "text/plain"
                            'body "")))
(register-api-func! (wffi-obj lib "Create user")
                    (lambda (d)
                      (hash 'Status "201 Created"
                            'date (seconds->gmt-string))))

(let ()
  (displayln (dispatch example-get-request))
  (displayln (dispatch example-get-request-CRLF))
  (displayln (dispatch example-post-request))
  ;; (displayln (dispatch upload-archive-request))
  (displayln (dispatch "GET /not-found HTTP 1.0\n\n")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
