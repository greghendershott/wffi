wffi ("whiffy") is an FFI for web services.

Specify a web service using a popular style of documentation. Get:

- Marshaling and routing code to implement it as a server.
- Marshaling code to use it as a client.
- Documention generated in formats like markdown and Scribble.

A "word cloud" of related concepts:

- Declarative (say what, not how).
- Literate programming.
- Specification by documentation.
- Separation of concerns.
- IDL, FFI, marshaling.

It is important to sepcify your web service's HTTP API precisely. Even
so, that isn't your web service's "true", semantic API.  This may
sound contradictory -- "the HTTP details are both important and not
important" -- but not if you separate concerns.

Let's start with documentation for part of a real-world web API, which
I'm taking almost verbatim from Amazon's documentation for Glacier.
The [HTML
version](http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-archive-post.html)
has some text italicized and in red. Here in plain text, I'm
highlighting that text using curly braces {}, which in fact is
actually a popular convention for web API docs:

-- REQUEST --

POST /{AccountId}/vaults/{VaultName}/archives
Host: glacier.Region.amazonaws.com
x-amz-glacier-version: 2012-06-01
Date: Date
Authorization: {SignatureValue}
x-amz-archive-description: {Description}
x-amz-sha256-tree-hash: {SHA256 tree hash}
x-amz-content-sha256: {SHA256 linear hash}
Content-Length: Length

-- RESPONSE --

HTTP/1.1 201 Created
x-amzn-RequestId: {x-amzn-RequestId}
Date: {Date}
x-amz-sha256-tree-hash: {ChecksumComputedByAmazonGlacier}
Location: {Location}
x-amz-archive-id: {ArchiveId}

What this illustrates is that many web service APIs are parameterized
across many parts of the HTTP request:

1. path elements
2. query parameters
3. headers
4. the entity, for `ContentType: application/x-www-form-urlencoded`

Parameters are allocated among some or all of these pqrts, according
to convention. But essentially there a function with one total set of
parameters on entry, and one total set of parameters on return.

A "routing" framework for a web service should not make too big a deal
of these various parts. If it helpfully decodes the path elemetns, but
not the others, it forces the handler function to get in the weeds.
For example, some of the parameters are passed to the handler as
function arguments ... but others need to be fished out of
an "all-other" params dictionary. This is ... weird. Also, this
conceptually binds the function to an HTTP request representation. But
there are architectures where the web service might be separated from
the front-end HTTP server by a layer of indirection -- for exmaple
using queues (redis or SQS), or say a unit-testing controller.

Furthermore, a web service is bi-directional. Getting parameters into
a handler function is one half. The other is getting values back
out. The HTTP _response_ may have outgoing data allocated among
various parts, such as the respsonse and the body.

In Racket a function can return multiple values, but they are not
named like function arguments are. Returning a struct isn't much
better. Although struct fields have names, the names aren't used to
create a struct. As a result, `(struct x y x)` is no safer
than `(values x y z)`. Both are by-position, and a bit fragile. A more
sensible choice for returning multiple values is to use a `dict`.

Well, if the output will be a dict, shouldn't the input, too?

So where this all leads, is:

- Any framwork's "routing" DSL should look like your web service's
HTTP API documentation: A parameterized request, and a parameterized
response.

- In fact your documentation should be _generated_ from this,
programatically and automatically.

- The handler function should get a `dict` for the request data, and
return a `dict` for the response data. Using `dict`s lets the handler
function focus on the _data_, without caring how they're marshaled
to/from a HTTP represenation. And in fact the data might be marshaled
into some other representation (like a queue), on its way to/from an
HTTP representation.


- TODO: The request and response templates should support Kleene
  stars. For instance imagine specifying the response's entity using
  this real-world example from Amazon Route 53:

HTTP/1.1 200 OK
Content-Type: application/xml
<?xml version="1.0" encoding="UTF-8"?>
<ListResourceRecordSetsResponse xmlns="https://route53.amazonaws.com/doc/2012-02-29/">
   <ResourceRecordSets>
      <ResourceRecordSet>
         <Name>{DNS domain name}</Name>
         <Type>{DNS record type}</Type>
         <TTL>{time to live in seconds}</TTL>
         <ResourceRecords>
            <ResourceRecord>
               <Value>{applicable value for the DNS record type}</Value>
            </ResourceRecord>
         </ResourceRecords>
      </ResourceRecordSet>
      ...
<ListResourceRecordSetsResponse>
