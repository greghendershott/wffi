#lang racket

(require wffi
         wffi/client
         )

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

#|
(require (planet gh/http))
(define lib (wffi-lib "example.md"))
(register-api! (get-wffi-obj lib "Example GET API")
               (lambda (d)
                 (hash 'Status "200 OK"
                       'date (seconds->gmt-string)
                       'type "text/plain"
                       'len 0
                       'body "")))
(register-api! (get-wffi-obj lib "Example POST API")
               (lambda (d)
                 (hash 'Status "201 Created"
                       'date (seconds->gmt-string))))

(let ()
  (displayln (dispatch example-get-request))
  (displayln (dispatch example-get-request-CRLF))
  (displayln (dispatch example-post-request))
  ;; (displayln (dispatch upload-archive-request))
  (displayln (dispatch "GET /not-found HTTP 1.0\n\n")))
|#

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Making requests as a client.
;; Example using wffi-lib, get-wiff-obj, get-wifi-obj/kw.


(require (planet gh/http))
(define lib (wffi-lib "example.md"))
(define get-example (get-wffi-obj/client-dict-proc lib "Example GET API"))
(define get-example/kw (get-wffi-obj/client-keyword-proc lib "Example GET API"))

(get-example (hash
              'user "greg"
              'item "12345"
              'a "A"
              'b "B" ;try comment this out to catch missing keyword
              ;;'UNDEFINED "UNDEFINED" ;try un-comment to catch undef kw
              'date (seconds->gmt-string)
              'endpoint "endpoint"
              'auth "auth"))

(get-example/kw #:user "greg"
                #:item "1"
                #:a "a"
                #:b "b" ;try comment this out to catch missing keyword
                ;;#:UNDEFINED "undefined" ;try un-comment to catch undef kw
                #:date (seconds->gmt-string)
                #:endpoint "endpoint"
                #:auth "auth")

(apply-dict get-example/kw
            (hash
             'user "greg"
             'item "12345"
             'a "A"
             'b "B" ;try comment this out to catch missing keyword
             ;;'UNDEFINED "UNDEFINED" ;try un-comment to catch undef kw
             'date (seconds->gmt-string)
             'endpoint "endpoint"
             'auth "auth"))
