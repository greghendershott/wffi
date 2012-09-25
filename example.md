# Example GET API

This is an example of a `GET` API.

## A subsection for the doc.

It is OK to include subsections for the documentation.

The following subsections are special. They must be level two ("##")
and they must be named exactly "Request:" and "Response:".

## Request:

    GET /user/{user}/items/{item}?a={a}&[b={b}] HTTP/1.1
    Host: {endpoint}
    Authorization: {auth}
    Date: {date}

## Response:

    HTTP/1.1 {Status}
    Date: {date}
    Content-Type: {type}
    Content-Length: {len}
    
    {body}

# Example POST API

This is an example of a `POST` request API.

## Request:

    POST /user/{user}/items/{item} HTTP/1.1
    Host: {endpoint}
    Authorization: {auth}
    Content-Type: application/x-www-form-urlencoded
    Content-Length: {len}

    a={a}&b={b}
    
## Response:

    HTTP/1.1 {Status}
    Date: {date}
    

# Create Domain

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

## Request:

    POST https://sdb.amazonaws.com/
      ?Action=CreateDomain
      &AWSAccessKeyId={public-key}
      &DomainName={domain}
      &SignatureVersion=2
      &SignatureMethod=HmacSHA256
      &Timestamp={timestamp}
      &Version=2009-04-15
      &Signature={sig}
    Date: {date}

## Response:

    HTTP 201 Created
    Date: {date}
    
    {body}

