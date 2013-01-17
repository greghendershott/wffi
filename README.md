# wffi: An FFI for web services

This uses the Markdown files from the
[webapi-markdown](https://github.com/greghendershott/webapi-markdown)
project.

Clone that project to somewhere on your system.

To use one of its `.md` files with `wffi-lib`, you may either:

- Supply the full pathname.

- Set the `current-markdown-files-path` parameter to the directory,
  then give `wffi-lib` only the basename.

## wffi-lib and wffi-obj

Given the path name of a markdown file, `wffi-lib` parses the file into
an `api?`.

Given an `api?` returned by `wffi-lib` and a `string` name, `wffi-obj`
finds an `api-function?` function by name.

## FFI for a client

From `client.rkt`:

Given an `api?` from `wffi-lib` and the name of a function,
`wffi-dict-proc` returns a `procedure` to call that web service
function.  The procedure takes a `dict` of inputs, makes the HTTP
request, and returns a `dict` of results.

Also see the variations `wffi-keyword-proc` and `wffi-rest-proc`.

## Framework for a server

See `server.rkt` for a bare-bones web service framework.
