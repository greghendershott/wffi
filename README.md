wffi
=====

wffi is an FFI for web services. (So as not to take myself too
seriously, I pronounce it "whiffy").

Specify a web service using DSL that is a popular style of
documentation. In return get:

- Marshaling and routing code to implement it as a server.
- Marshaling code to use it as a client.
- Documention in formats like markdown and Scribble.

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
I'm taking almost verbatim from Amazon's documentation for Glacier:

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

    -- RESPONSE --

    HTTP/1.1 201 Created
    x-amzn-RequestId: {x-amzn-RequestId}
    Date: {Date}
    x-amz-sha256-tree-hash: {ChecksumComputedByAmazonGlacier}
    Location: {Location}
    x-amz-archive-id: {ArchiveId}

Amazon's [HTML
version](http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-archive-post.html)
uses a red/italic text style for the parameters. Here in plain text,
I'm marking them using curly braces {}. That's actually a popular
convention for web documentation.

What this illustrates is that web service APIs are parameterized
across many parts of the HTTP request:

1. path elements
2. query parameters
3. headers
4. the entity, for `ContentType: application/x-www-form-urlencoded`

Parameters are allocated among some or all of these parts, according
to convention or (sometimes it seems) the specifier's previous meal..
Regardless, there is a function with one total set of parameters on
entry and one total set of parameters on return.

Some decisions
--------------

On the server side (if you're implementing such a service), any
"routing" framework shouldn't make _too_ big a deal of where in the
HTTP the interesting data is located (path, query, heads, entity).

Some frameworks decode the path elements and pass them as regular
function arguments to a handler function, whereas the other inputs
must be fished out of one or more "params" dictionaries.

This is weird, and it conceptually binds the function to an HTTP
request representation. But RESTful web services don't have to use
HTTP. Even when they do, there are architectures where the web service
might be separated from the front-end HTTP server by a layer of
indirection (such as queues, or a unit-test harness).

Also, there is both input and output. Marshaling values from a
_request_ into a handler function is one half. The other is getting
values back out; the services' HTTP _response_ also may have outgoing
data allocated among various parts, such as the status, headers, and
entity.

In Racket a function can return multiple values, but they are not
named like function arguments are. Returning a struct isn't much
better. Although struct fields have names, the names aren't used to
create a struct. Saying `(struct x y x)` is no safer than `(values x y
z)`. Both are by-position and a bit fragile. A more sensible choice
for returning multiple values is to use a `dict`.

Well, if the output will be a dict, shouldn't the input, too?

So where this all leads, is:

- Specification for a web service should look like the _documentation_
  for a web service: A parameterized request, and a parameterized
  response. In fact, we decide that they will be the same thing: A
  markdown file of a certain structure.

    ---
    # API function name

    One or more paragraphs of documentation, using full markdown
    formatting.

    ## Request:

        GET /users/{user}/thing/{id} HTTP/1.1
        Date: {date}

    ## Response:

        HTTP/1.1 {status}
        Content-Type: text/plain
        Content-Length: {len}
        
        {body}

    ---

- A server handler function gets a `dict` for the request data, and
  returns a `dict` for the response data. Using `dict`s lets the
  handler function focus on the _data_, without caring how they're
  marshaled to/from a HTTP represenation. And in fact the data might
  be marshaled into some _other_ representation (like a queue), on its
  way to/from an HTTP representation or non-HTTP representation (like
  a unit test harness).

- It is easy enough in Racket to create (programatically) a wrapper
  function that takes individual `#keyword` arguments instead of a
  `dict`. If someone prefers that style, they can use that.

- A DSL that describes parameterized requests and responses is a fine
  way to specify a server implementation --- and also a client
  implementation. After all, a web client is also prone to spending
  more effort marshaling than solving its core problem.


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
