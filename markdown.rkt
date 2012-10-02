#lang racket

(require "api.rkt"
         "split.rkt"
         "parse-markdown.rkt"
         "parse-request.rkt"
         "parse-response.rkt"
         )

(provide wffi-lib
         wffi-obj
         markdown->apis
         api->markdown)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define/contract (wffi-lib s)           ;truly markdown->wffi-lib
  (path-string? . -> . (listof api?))
  (call-with-input-file s markdown->apis))

(define/contract (wffi-obj lib name)
  ((listof api?) string? . -> . api?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (cond [a a]
        [else (error 'wffi-obj "can't find ~s" name)]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define/contract (markdown->apis in)
  (input-port? . -> . any #|(listof apis)|#)
  (filter-map md-section-group->api (parse-markdown in)))

(require parser-tools/lex)
(define (md-section-group->api m)
  (match m
    [(md-section-group (md-section 1 name docs) subs)
     (define req (parse-req subs))
     (define resp (parse-resp subs))
     (cond
      [req
       (match-define (list (list req-method (list req-path req-query) http-ver)
                           req-head
                           req-body) req)
       (match-define (list resp-stat resp-head resp-body) resp)
       (init-api name (string-join docs "") "" "" ;;req resp
                 req-method req-path req-query req-head resp-head)]
      [else #f])]
    [else #f]))

(define (parse-req subs)
  (match subs
    [(list-no-order (md-section 2
                                (or "Request" "Request:")
                                (list-no-order (md-code-block beg end code)
                                               _ ...))
                    _ ...)
     (call-parser parse-template-request code beg)]
    [else #f]))

(define (parse-resp subs)
  (match subs
    [(list-no-order (md-section 2 (or "Response" "Response:")
                                (list-no-order (md-code-block beg end code)
                                               _ ...))
                    _ ...)
     (call-parser parse-template-response code beg)]
    [else '(() () ())]))

(define/contract (call-parser f code pos)
  (procedure? bytes? position? . -> . any)
  (let ([in (open-input-bytes code)])
    (port-count-lines! in)
    (set-port-next-location! in
                             (position-line pos)
                             (position-col pos)
                             (position-offset pos))
    (f in)))

;; test
;; (wffi-lib "example.md")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Return a string with documentation for the API, in markdown format.
;; Not hard, since we kept the original markdown fragments.
(define/contract (api->markdown x)
  (api? . -> . string?)
  (string-append "# " (api-name x) "\n"
                 "\n"
                 (api-desc x) "\n"
                 "\n"
                 "## Request:\n"
                 "\n"
                 (api-req x) "\n"
                 "\n"
                 "## Response:\n"
                 "\n"
                 (api-resp x) "\n"
                 "\n"
                 ))

;; Return documentation for the API, in Scribble format.
(define/contract (api->scribble a)
  (api? . -> . any/c)
  (error 'api->scribble "TO-DO")
  "")
