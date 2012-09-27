# Example GET API

This is an example of a `GET` API.

## A subsection for the doc.

It is OK to include subsections for the documentation.

The following subsections are special. They must be level two ("##")
and they must be named exactly "Request:" and "Response:".

The request grammar allows you to omit some parts:

- You may omit the HTTP/1.0 or HTTP/1.1 ending on the request start line.

- You do not need to specify any body.

## Request:

    GET /user/{user}/items/{item}?a={a}&b={b} HTTP/1.1
    Host: {}
    Authorization: {}
    Date: {}

## Response:

    HTTP/1.1 200 OK
    Date: {}
    Content-Type: {type}
    Content-Length: {len}

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

    HTTP/1.1 200 OK
    Date: {date}
    
    {body}

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

    POST /
      ?Action=CreateDomain
      &AWSAccessKeyId={public-key}
      &DomainName={domain}
      &SignatureVersion=2
      &SignatureMethod=HmacSHA256
      &Timestamp={timestamp}
      &Version=2009-04-15
      &Signature={}
    Date: {}

## Response:

    HTTP 201 Created
    Date: {date}
