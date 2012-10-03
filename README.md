# wffi: An FFI for web services

A web service is both documented and specified using a markdown file.

Like "literate programming", this is "literate web service
specification".

The same markdown file can be used for any/all of three purposes:

1. Used verbatim as the publishable documentation of the web service.

2. Parsed to support an FFI for clients to use the web service. Making
it easier to structure requests and to destructure responses.

3. Parsed to support a web service framework for servers to provide
the service. Making it easier to route and destructure requests and
to stucture responses.

This project implements a Racket language parser, FFI, and service
framework. However the markdown layout and message template is not
specific to any programming language or style.


# Quick Start

The markdown file may consist of multiple sections. Some may be purely
for documentation. Others will be recognized as specifying a web
service function.

For a section of a markdown file to be utilized as a function
specification, it must use a certain format:

---

    # Name of API function

    The section level 1 heading above is used as the name of the API
    function.

    Documentation text here. Use full markdown formatting.

    ## Optional subsection(s) with more documentation

    If you need more subsections for documentation, you may use them.

    ## Request

    A section level 2 named "Request" is special. It may contain an
    HTTP request template, inside of a code block using the ````
    markers (the indented 4 spaces style is ignored). For instance:

    ````
    GET /user/{user}/items/{item}
        ?qp1={}
        &[qp2={}]
    Header1: {}
    Header2: {alias}
    ````
    
    Other than the code block, the rest of the section is purely for
    documentation.
    
    If you need a code block in this section that is _not_ the
    template, then use the other code block style -- indenting with
    four spaces:
    
        Here's a code block using
        the indented spaces style.
        It won't be confused with
        the template.
    
    ## Response:

    Likewise, a section level 2 named "Response" is special. It may
    contain an HTTP response template.  For instance:
    
    ````
    HTTP/1.1 200 OK
    Date: {}
    Content-Type: {}
    Content-Length: {}
    ````

    ## Other sections
    
    There may be other sections for documentation purposes.
 
---

The special `Request` and `Response` sections:

1. Must be level 2, using `##`, "under" (following) a level 1 section
   specified using `#`. (The "underline style" of marking sections is
   not recognized.)

2. Must be named exactly `Request:` and `Response:` respectively
   (although the trailing colon in optional).

The `Response` section is optional:

   - **Client**: The response template may be omitted if this is to be
     used solely for an FFI for a client. Because an FFI will probably
     just put the response status and _all_ the response headers in a
     dictionary. Plus much of the interesting stuff is in the response
     entity (body), and it is beyond the scope of this to try to
     parameterize formats varying from JSON to XML to whatever. Even
     so, it may be may be helpful to include the section for
     documentation value, at least if the response includes special
     headers.

   - **Server**: If this is to be used when implementing a server, the
     `Response` section should be mandatory. It's helpful
     documentation. Plus a server framework might use the response
     template to assist preparing the HTTP response. Doing so is good
     because your documentation and actual behavior stay in sync.


## HTTP message templates

The HTTP message templates are very similar to what you see in
real-world web service documentation. They look like simplified HTTP
requests and responses, with some of the parts constant and others
variable (parameterized).

### Conveniences

The templated HTTP message grammar allows you to omit some parts that
are normally required in an HTTP message:

- You may omit the `HTTP/1.0` or `HTTP/1.1` ending on the request
  start line.

- You do not need to specify any body (entity).

A long series of query parameters may be split across multiple lines
using indenting, following a common style (e.g. Amazon). For instance:

````
POST /some/path/
     ?qp1=1
     &qp2=2
     &qp3=3
Header0: Value0
Header1: Value1
   ... <remainder of request> ...
````

### Key/value notation

A request includes key/value pairs in various places, such as
`Key=Value` query parameters and `Key: Value` headers.  The template
allows these to be treated as one union of key/value pairs (for
example, in a dictionary) independent of where they appear in the HTTP
message.

There are four permutations of constant vs. variable and required
vs. optional. Each permutation is discussed from the point of view of
a server and an FFI for clients. The notation below uses just
`Key=Value` as for query parameters, but equally applies to
`Key: Value` headers.

- `Key=Value` means that the header or parameter is a **constant**.
  - Server: Requires it to be supplied literally with the value
    `Value`.
  - Client: Must supply it literally. For convenience an FFI should
    supply it for a client automatically.
- `Key={}` _or_ `Key={alias}` means that the header or parameter is
   **variable**.
  - Server: Requires _some_ value to be supplied.
  - Client: An FFI must require client to supply some value. In the
    client code, the name (e.g. dict key or keyword arg) is `K` when
    `{}`, otherwise `alias`. (In other words a long header name can be
    given a shorter alias.)
- `[Key=Value]` means that the **constant** header or parameter is
  **optional**.
  - Server: When the header or parameter is not supplied in the
    request, the server will assume the constant value `Value` had
    been supplied.
  - Client: When the client doesn't supply anything, the FFI will
    automatically supply `Key=Value` to the server.  (If the client
    wants to supply a value, it must use the name `Key`; in this
    variant there is no alias.)
- `[Key={}]` _or_ `[Key={alias}]` means that the **variable** header or
  parameter is **optional**.
  - Server: Will assume no particular value if not supplied.
  - Client: The client may supply this or not.

The following request template has examples of these:

````
GET /user/{user}/items/{item}
    ?query-param={}
    &[optional-query-param={}]
    &constant-query-param=1
    &[optional-constant-query-param=1]
Header: {}
Header-With-Alias: {alias}
Header-With-Contant-Value: Constant Value
[Optional-Header-With-Variable-Value: {}]
[Optional-Header-With-Contant-Value: 10000]
````

## BNF for templated requests

** TO-DO **

## BNF for templated responses

** TO-DO **

---
---
---

# Examples

The remainder of this document contains sections that fit the
format. In other words, this markdown document is itself a
specification for an imaginary web service. Running it through a
compliant parser should extract the specification of three web service
functions, "Example Get API", "Example POST API", and "Create Domain".

---

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

> > _Note_: This section is me cribbing some AWS SDB documentation. In
> >  other words, creating this markdown file for an existing web service
> >  should be _almost_ a copy-and-paste excercise. That's the idea,
> >  anyway.

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

---
---
---

# Racket-specific

## wffi-lib and wffi-obj

From `markdown.rkt`:

Given the pathname of a markdown file, `wffi-lib` parses the file into
a `(listof api?)`, where each `api` corresponds to one web service
function.

Given a `wffi-lib` and a `string` name, `wffi-obj` finds a function by
name.

## FFI for a client

From `client.rkt`:

Given a `wffi-lib` and the name of a function, `wffi-dict-proc`
returns a `procedure` to call that web service function.  The
procedure takes a `dict` of inputs, makes the HTTP request, and
returns a `dict` of results.

## Framework for a server

See `server.rkt` for a barebones web service framework.
