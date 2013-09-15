# Example service

Endpoint: http://www.racket-lang.org

# Get user

This is an example of a `GET`.

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

# Create user

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

## Response:

````
HTTP/1.1 200 OK
Date: {}
Content-Type: {}
Content-Length: {}
````
