# Introduction

For a section of a markdown file to be used as a web API function, it
must use a certain format:

---

    # Name of API

    Documentation text here. Use full markdown formatting.

    ## Optional subsection(s) with more documentation

    If you need more subsections for documentation, you may use them.

    Then, the section must end with the following two subsections, in
    this order:
    
    ## Request:

    A templated HTTP request message, as a code block using markdown's
    ```` notation.

    ## Response:

    A templated HTTP response message, as a code block using
    markdown's ```` notation.
 
---

Note that only the `#` and `##` section/level syntax is supported
(_not_ the style where you put an "underline" on the line following
the setion title).

Note that the templated subsections:

1. Must be level 2 (`##`).

2. Must be named exactly `Request:` and `Response:` respectively
   (although the trailing colon in optional).

3. Must be in that order.

4. Must be the final two subsections.

5. The `Response` section is optional if this is to be used solely for
   an FFI for a client, although it may be helpful for documentation
   if the response includes special headers.

## Templated HTTP message

The templated HTTP message grammar allows you to omit some parts that
are normally required in an HTTP message:

- You may omit the HTTP/1.0 or HTTP/1.1 ending on the request start
  line.

- You do not need to specify any body (entity).

As another aid, a long series of query parameters may be split into
multiple lines with indenting, following a common style
(e.g. Amazon). For instance:

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

There are four permutations of constant vs. variable and required
vs. optional. Each permutation is discussed from the point of view of
a server and an FFI for clients:

- `K: V` means that the header or parameter is a constant. Server
  requires it to be supplied literally.  An FFI should supply them
  for a client automatically.

- `K: {}` _or_ `K: {alias}` means that a header or parameter is
  variable.  Server requires some value to be supplied. An FFI must
  require client to supply the value (in a dict or a keyword arg)
  under a name. The name is `K` when `{}`, otherwise `alias`.

- `[K: V]` means that the constant parameter is optional. Server will
  assume the value `V` when not supplied. FFI will supply `K: V`
  automatically unless the client supplies another value under the
  name `K`.  (In this case, no ability to alias the name `K`.)

- `[K: {}]` _or_ `[K: {alias}]` means that the header or parameter is
  optional. Server will assume no particular value if not
  supplied. FFI will suppply `K: V` if the client has supplied it,
  otherwise it will supply nothing at all to the server.


## BNF for the templated messages

** TO-DO **

## Examples

The remainder of this document contains sections that fit the
format. In other words, this markdown document is itself a
specification for an imaginary web service.

# Example GET API

This is an example of a `GET` API.

## A subsection for the doc.

It is OK to include subsections for the documentation.

## Request:

````
GET /user/{user}/items/{item}?qa={}&[qb={}] HTTP/1.1
Host: {}
Header-With-Alias: {alias}
Authorization: {}
Constant: Constant Value
[Optional-Var: {}]
[Optional-Const: 10000]
Date: {}
````

## Response:

The `Response` section is optional when this file is being used by an
FFI for clients. However if the function returns any special headers,
it would be good to include the section for documentation
purpose. Anyway it is mandatory when using this to implement a server.

````
HTTP/1.1 200 OK
Date: {}
Content-Type: {}
Content-Length: {}
````

# Example POST API

This is an example of a `POST` request API.

## Request:

````
POST /user/{user}/items/{item} HTTP/1.1
Host: {endpoint}
Authorization: {auth}
Content-Type: application/x-www-form-urlencoded
Content-Length: {len}

a={a}&b={b}
````

# Create Domain

> _Note_: This section is me cribbing some AWS SDB documentation. In
>  other words, creating this markdown file for an existing web service
>  should be _almost_ a copy-and-paste excercise. That's the idea,
>  anyway.

The CreateDomain operation creates a new domain. The domain name must
be unique among the domains associated with the Access Key ID provided
in the request. The CreateDomain operation might take 10 or more
seconds to complete.

> _Notes_:

> CreateDomain is an idempotent operation. Running it multiple times
using the same domain name will not result in an error response.

> You can create up to 250 domains per account.

> If you require additional domains, go to
<http://aws.amazon.com/contact-us/simpledb-limit-request/>.

## Request:

````
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
````

## Response:

