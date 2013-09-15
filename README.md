# wffi: An FFI for web services

This uses Markdown files of the format described by the
[webapi-markdown](https://github.com/greghendershott/webapi-markdown)
project.

# Install

    raco pkg install wffi

You may be prompted to install a couple other packages.

# Client

To create Racket client wrapper functions for all the web API
functions defined in the `.md` file:

```racket
(require wffi/client)
(wffi-define-all "path/to/file.md" values values)
(provide (all-defined-out))
```

If the web service has a parameter common to all of its functions --
for example an `api_key` query parameter, or an authorization request
header -- you can define a function to add that, and supply the
function as the `before` argument to `wffi-define-all`. For example:

```racket
(require wffi/client)
(define (add-common-parameters d)
  (dict-set* d 'api_key "MY-API-KEY"))
(wffi-define-all "path/to/file.md" add-common-parameters values)
(provide (all-defined-out))
```

If the service responds with JSON, you can supply
`check-response/json` (a helper function provided by `wffi/client`) as
the `after` argument to `wffi-define-all`. The previous example with
that change:

```racket
(require wffi/client)
(define (add-common-parameters d)
  (dict-set* d 'api_key "MY-API-KEY"))
(wffi-define-all "path/to/file.md" add-common-parameters check-response/json)
(provide (all-defined-out))
```

Of course, if the web service responds with XML or some other format,
you can write your own `after` function. See the definition of
`check-response/json` in `wffi/client.rkt` to see how.

## Framework for a server

See `server.rkt` for a bare-bones web service framework.
