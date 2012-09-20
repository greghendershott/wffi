wffi
=====

wffi is an FFI for web services. (So as not to take myself too
seriously, I pronounce it "whiffy").

Specify a web service using DSL that is a popular style of
documentation. In return get:

- Marshaling and routing code to implement it as a server.
- Marshaling code to use it as a client.
- Documention generated in formats like markdown and Scribble.

A "word cloud" of (somewhat) related concepts:

- Declarative (say what, not how).
- Specification by documentation.
- Literate programming.
- Separation of concerns.
- IDL, FFI, marshaling.

HTTP vs. semantics
------------------

It is important to sepcify your web service's HTTP API precisely and
(in my opinion) using solid RESTful principles. At the same time, the
HTTP API isn't your web service's "true", semantic API.  This may
sound contradictory -- "the HTTP details are important and not
important" -- but not if you separate concerns. In fact separating
concerns can make it easier to do a better job with each one,
precisely because they aren't so tightly coupled.

Let's start with documentation for part of a real-world web API, which
I'm taking almost verbatim from Amazon's documentation for Glacier.
The [HTML
version](http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-archive-post.html)
has some text italicized and in red. Here in plain text, I'm
highlighting that text using curly braces {}, which in fact is
actually a popular convention for web API docs:

    -- REQUEST --

    POST /{AccountId}/vaults/{VaultName}/archives
    Host: glacier.{Region}.Amazonaws
    x-amz-glacier-version: 2012-06-01
    Date: {Date}
    Authorization: {SignatureValue}
    x-amz-archive-description: {Description}
    x-amz-sha256-tree-hash: {SHA256 tree hash}
    x-amz-content-sha256: {SHA256 linear hash}
    Content-Length: {Length}

    -- Response --

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

Parameters are allocated among some or all of these parts, according
to convention or just the author's mood.  But essentially there is a
function with one total set of parameters on entry, and one total set
of parameters on return.

A "routing" framework for a web service should not make too big a deal
of these various parts. If it helpfully decodes the path elements, but
not the other parts of a request, it forces the handler function to
get in the weeds.  For example, some of the parameters are passed to
the handler as function arguments ... but others need to be fished out
of an "all-other" params dictionary. This is ... weird. Also, this
conceptually binds the function to an HTTP request representation. But
there are architectures where the web service might be separated from
the front-end HTTP server by a layer of indirection such as queues, or
or say a unit-testing controller.

Furthermore, a web service is bi-directional. Marshaling values into a
handler function is one half. The other is getting values back
out. The HTTP _response_ also may have outgoing data allocated among
various parts, such as the status, headers, and entity.

In Racket a function can return multiple values, but they are not
named like function arguments are. Returning a struct isn't much
better. Although struct fields have names, the names aren't used to
create a struct. Saying `(struct x y x)` is no safer than `(values x y
z)`. Both are by-position and a bit fragile. A more sensible choice
for returning multiple values is to use a `dict`.

Well, if the output will be a dict, shouldn't the input, too?

So where this all leads, is:

- The routing DSL for a web service framework should look like the
  _documentation_ for your web service: A parameterized request, and a
  parameterized response.

- In fact your documentation should be _generated_ from this DSL
  programatically and automatically.

- The handler function should get a `dict` for the request data, and
  return a `dict` for the response data. Using `dict`s lets the
  handler function focus on the _data_, without caring how they're
  marshaled to/from a HTTP represenation. And in fact the data might
  be marshaled into some _other_ representation (like a queue), on its
  way to/from an HTTP representation or non-HTTP representation (like
  a unit test harness).

- A DSL that describes parameterized requests and responses is a fine
  way to specify a server implementation --- and also a client
  implementation. After all, a web client is also prone to spending more effort marshaling than solving its core problem.


Open questions
--------------

Other than the special case of a form URL encoded POST entity, should
we try to parameterize request and response entities? Perhaps that's
taking the idea a step too far. Query parameters, headers, and many
paths are all just key/value dictionaries dressed up in various ways.
But many request and response entites are not simply dictionaries,
they are things like XML and JSON. Maybe we should leave well enough
alone.

If we do attempt that, we'll need/want some more advanced templating,
such as Kleene stars for repeating pattenrns.

For instance imagine specifying the response's entity using this
real-world example from Amazon Route 53:

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
