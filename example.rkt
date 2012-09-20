#lang racket

(require http/request
         wffi)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defapi example-get-api
  "Example GET API"
  ["This is an example of a `GET` API. You may use _markdown_ here."
   "This is a `(listof string?)`, that will be joined by newlines."
   "You may also use a Racket reader \"here string\" to supply multiple"
   "lines as a single string."]
  ["GET /user/{user}/items/{item}?a={a}&b={b} HTTP/1.1"
   "Host: {endpoint}"
   "Authorization: {auth}"
   "Date: {date}"]
  ["HTTP/1.1 {Status}"
   "Date: {date}"
   "Content-Type: {type}"
   "Content-Length: {len}"
   ""
   "{body}"]
  ;; Handler function expressions. `d' is the input dictionary.
  (displayln "Input dict is:")
  (pretty-print d)
  (hash 'Status "200 OK"
        'date (seconds->gmt-string)
        'type "text/plain"
        'len 0
        'body ""))

(defapi example-post-api
  "Example POST API"
  ["This is an example of a `POST` request API. You may use _markdown_ here."]
  ["POST /user/{user}/items/{item} HTTP/1.1"
   "Host: {endpoint}"
   "Authorization: {auth}"
   "Content-Type: application/x-www-form-urlencoded"
   "Content-Length: {len}"
   ""
   "a={a}&b={b}"]
  ["HTTP/1.1 {Status}"
   "Date: {Date}"
   ""
   "{body}"]
  ;; Handler function expressions. `d' is the input dictionary.
  (displayln "Input dict is:")
  (pretty-print d)
  (hash 'Status "200 OK"
        'Date (seconds->gmt-string)
        'body "fed77asdff"))

;; Complicated real-world example: The Amazon Glacier "upload archive" API.
;;
;; This example also shows using "here strings", which are a feature of
;; the Racket reader.
(defapi example-upload-archive-api
  "Upload Archive"
  ["This operation adds an archive to a vault. For a successful upload,
your data is durably persisted. In response, Amazon Glacier returns
the archive ID in the x-amz-archive-id header of the response. You
should save the archive ID returned so that you can access the archive
later.

You must provide a SHA256 tree hash of the data you are uploading. For
information about computing a SHA256 tree hash, see Computing
Checksums.

When uploading an archive, you can optionally specify an archive
description of up to 1,024 printable ASCII characters. Amazon Glacier
returns the archive description when you either retrieve the archive
or get the vault inventory. Amazon Glacier does not interpret the
description in any way. An archive description does not need to be
unique. You cannot use the description to retrieve or sort the archive
list."]
[#<<--
POST /{account-id}/vaults/{vault-name}/archives HTTP/1.1
Host: {host}
x-amz-glacier-version: {version}
Date: {date}
Authorization: {signature}
x-amz-archive-description: {description}
x-amz-sha256-tree-hash: {tree-hash}
x-amz-content-sha256: {linear-hash}
Content-Length: {length}

--
]
[#<<--
HTTP/1.1 {Status}
x-amzn-RequestId: {x-amzn-RequestId}
Date: {Date}
x-amz-sha256-tree-hash: {ChecksumComputedByAmazonGlacier}
Location: {Location}
x-amz-archive-id: {ArchiveId}

--
]
;; Handler function expressions. `d' is the input dictionary.
(displayln "Input dict is:")
(pretty-print d)
(hash 'Status "201 Created"
      'x-amzn-RequestId "adsfadf"
      'Date (seconds->gmt-string)
      'ChecksumComputedByAmazonGlacier "asdfadsf"
      'Location "http://foo/bar.com"
      'ArchiveId "adsfasdfadsf"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; For testing, some requests
;;
;; Should this actually be a field in `api'?

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

;; Show the table
;; (pretty-print hapi)

;; ;; Generate documentation for the entire API.
;; (displayln (string-join (map api->markdown (apis)) "\n"))

;; Use the api to receive requests as a server and dispatch them.
#|
(let ()
  (displayln (dispatch example-get-request))
  (displayln (dispatch example-get-request-CRLF))
  (displayln (dispatch example-post-request))
  (displayln (dispatch upload-archive-request))
  (displayln (dispatch "GET /not-found HTTP 1.0\n\n")))
|#

;; For each API function, show its name, inputs, outputs.
#|
(pretty-print
 (map list
      (map api-name (apis))
      (map api-inputs (apis))
      (map api-outputs (apis))))
|#

;; (for-each pretty-print (apis))

;; Use the api to make a request as a client.
#|
(define (pretend-authorizer d)
  ;; pretend some kind of auth based on other values in dict
  (string-join (list (dict-ref d 'user) (dict-ref d 'item) (dict-ref d 'date))
               "++"))
(displayln (dict->request example-get-api
                          (hash 'user "greg"
                                'item "1"
                                'a "a"
                                'b "b"
                                'date (seconds->gmt-string)
                                'endpoint "endpoint"
                                'auth pretend-authorizer)))
(displayln (response->dict example-get-api
                           example-get-response))
|#

;; Procedures taking keyword arguments in lieu of a single dict? arg:

(define f (make-api-keyword-procedure example-get-api))
(apply-dict f (hash 'user "greg"
                    'item "1"
                    'a "a"
                    'b "b"
                    ;;'UNDEFINED "UNDEFINED" ;test cathing bad keyword
                    'date (seconds->gmt-string)
                    'endpoint "endpoint"
                    'auth "auth"))
(f #:user "greg"
   #:item "1"
   #:a "a"
   #:b "b"
   ;;#:UNDEFINED "undefined" ;test catching bad keyword
   #:date (seconds->gmt-string)
   #:endpoint "endpoint"
   #:auth "auth")
