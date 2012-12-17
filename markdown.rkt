#lang racket

(require parser-tools/lex
         "api.rkt"
         "split.rkt"
         "parse-markdown.rkt"
         "parse-request.rkt"
         "parse-response.rkt"
         )

(provide wffi-lib
         wffi-obj
         markdown->apis
         api->markdown)

(define current-source (make-parameter ""))

(define/contract (wffi-lib s)
  (path-string? . -> . (listof api?))
  (parameterize ([current-source s])
    (call-with-input-file s markdown->apis)))

(define/contract (wffi-obj lib name)
  ((listof api?) string? . -> . api?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (or a (error 'wffi-obj "can't find ~s" name)))

(define/contract (markdown->apis in)
  (input-port? . -> . (listof api?))
  (filter-map md-section-group->api (parse-markdown in)))

(define (md-section-group->api m)
  (match m
    [(md-section-group (md-section 1 name docs) subs)
     (define req (parse-req subs))
     (define resp (parse-resp subs))
     (cond [req
            (match-define (list (list req-method (list req-path req-query) ver)
                                req-head req-body) req)
            (match-define (list resp-stat resp-head resp-body) resp)
            (init-api name (string-join docs "")
                      req-method req-path req-query req-head resp-head)]
           [else #f])]  ;ignore this section
    [else #f]))         ;ignore this section

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

;; Cqll the parser `f` on the `code`, setting the port location to
;; `pos` so that error reporting will be for the the containing file
;; from which we got the code. Also uses the `current-source`
;; parameter which is the name of teh source file.
(define/contract (call-parser f code pos)
  (procedure? bytes? position? . -> . any)
  (define in (open-input-bytes code))
  (port-count-lines! in)
  (set-port-next-location! in
                           (position-line pos)
                           (position-col pos)
                           (position-offset pos))
  (f (current-source) in))

;; ;; test
;; (wffi-lib "examples/example.md")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Return a string with documentation for the API, in markdown format.
;; Not hard, since we kept the original markdown fragments.
(define/contract (api->markdown x)
  (api? . -> . string?)
  (string-append "# " (api-name x) "\n"
                 "\n"
                 (api-desc x) "\n"
                 ))

;; Return documentation for the API, in Scribble format.
(define/contract (api->scribble a)
  (api? . -> . any/c)
  (error 'api->scribble "TO-DO")
  "")
