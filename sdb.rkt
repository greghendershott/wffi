#lang racket

(require wffi)

(defapi create-domain
  "Create Domain"
[#<<--

The CreateDomain operation creates a new domain. The domain name must
be unique among the domains associated with the Access Key ID provided
in the request. The CreateDomain operation might take 10 or more
seconds to complete.

Note:

CreateDomain is an idempotent operation. Running it multiple times
using the same domain name will not result in an error response.

You can create up to 250 domains per account.

If you require additional domains, go to
http://aws.amazon.com/contact-us/simpledb-limit-request/.

--
 ]
[#<<--
https://sdb.amazonaws.com/?Action=CreateDomain&AWSAccessKeyId={public-key}&DomainName={domain}&SignatureVersion=2&SignatureMethod=HmacSHA256&Timestamp={timestamp}&Version=2009-04-15&Signature={sig}
Date: {date}

--
]
[#<<--
HTTP 201 Created
Date: {date}

{body}
--
]
 (hash)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (sign-sdb-request d s)
  ;;(printf "d=~v\ns=~s\n" d s)
  "fake-signature")

(dict->request create-domain
               (hash 'public-key "asdfasdf"
                     'domain "myDomain"
                     'timestamp "asdfasdf"
                     'date "asdfasdf"
                     'sig sign-sdb-request))
