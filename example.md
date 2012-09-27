# Example GET API

This is an example of a `GET` API.

## A subsection for the doc.

It is OK to include subsections for the documentation.

The following subsections are special. They must be level two ("##")
and they must be named exactly "Request:" and "Response:".

The request grammar allows you to omit some parts:

- You may omit the HTTP/1.0 or HTTP/1.1 ending on the request start
    line.

- You do not need to specify any body (entity).

A long series of query parameters may be split into multiple lines
with indenting, following a common style (e.g. Amazon). For instance:

    POST /some/path/
      ?qp1=1
      &qp2=2
      &qp3=3
    Date: blah blah blah
    ... remainder of request ...

A request includes `Key Value` pairs in various places, such as the
`Key=Value` query parameters and the `Key: Value` headers.  The
template allows these to be treated as key/value pairs independent of
where they apepar in the HTTP message -- for example, in a dictionary
or as keyword arguments.

- `K: V` means that the key and value are constants. Server requires
  them as-is. FFI will supply them for client automatically, client
  doesn't need to specify.

- `K: {}` or `K: {alias}` means that a value must be supplied. Server
  requires some value to be supplied. FFI requires client to supply
  the value under a name (in a dict or a keyword arg). The name is `K`
  when `{}`, otherwise `{name}.

- `[K: V]` means that the key/value are optional. Server will assume
  the value `V` when not supplied. FFI will supply `K: V`
  automatically unless the client supplies another value under the
  name `K`. Note that no ability to alias the name `K`.

- `[K: {V}]` means that the ke/value are optional. Server will assume
  no particular value if not supplied. FFI will suppply `K: V` if the
  client has supplied it, otherwise it will supply nothing at all to
  the server.

## Request:

    GET /user/{user}/items/{item}?qa={}&[qb={}] HTTP/1.1
    Host: {}
    Header-With-Alias: {alias}
    Authorization: {}
    Constant: Constant Value
    [Optional-Var: {}]
    [Optional-Const: 10000]
    Date: {}

## Response:

    HTTP/1.1 200 OK
    Date: {}
    Content-Type: {}
    Content-Length: {}

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

> _Notes_:

> CreateDomain is an idempotent operation. Running it multiple times
using the same domain name will not result in an error response.

> You can create up to 250 domains per account.

> If you require additional domains, go to
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
