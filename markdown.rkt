#lang racket

(require parser-tools/lex
         "api.rkt"
         "split.rkt"
         "parse-markdown.rkt"
         "parse-request.rkt"
         "parse-response.rkt"
         )

(provide current-markdown-files-path
         wffi-lib
         wffi-obj
         markdown->api
         api-func->markdown)

(define current-source (make-parameter ""))

(define current-markdown-files-path
  (make-parameter (build-path
                   (find-system-path 'home-dir) "src" "webapi-markdown")))

(define (file-exists s)
  (and (file-exists? s) s))

(define (file-exists-in-md-dir s)
  (and (current-markdown-files-path)
       (not (regexp-match? #px"^\\s*$" (current-markdown-files-path)))
       (file-exists (build-path (current-markdown-files-path) s))))

(define (find-md-file s)
  (define rtn (or (file-exists s)
                  (file-exists-in-md-dir s)))
  (unless rtn
    (error 'wffi-lib "Can't find webapi markdown file ~s" s))
  rtn)

(define/contract (wffi-lib s)
  (path-string? . -> . api?)
  (let ([s (find-md-file s)])
    (parameterize ([current-source s])
      (call-with-input-file s markdown->api))))

(define/contract (wffi-obj lib name)
  (api? string? . -> . api-func?)
  (define funcs (api-funcs lib))
  (define a (findf (lambda (x) (string=? name (api-func-name x))) funcs))
  (or a (error 'wffi-obj "can't find ~s" name)))

(define/contract (markdown->api in)
  (input-port? . -> . api?)
  (define xs (parse-markdown in))
  (define endpoint
    (match xs
      [(list 1st rst ...) (md-section-group->endpoint 1st)]
      [else (error 'markdown->api
                   "\"\nEndpoint: <URI>\n\" not found in first section.")]))
  (api endpoint
       (filter-map md-section-group->api-func xs)))

(define (md-section-group->endpoint m)
  (match m
    [(md-section-group (md-section 1 name docs) subs)
     (match docs
       [(list-no-order (pregexp "(?i:Endpoint:\\s+)(\\S+)\n" (list _ e)) _ ...)
        e]
       [else #f])]
    [else #f]))
       
(define (md-section-group->api-func m)
  (match m
    [(md-section-group (md-section 1 name docs) subs)
     (define req (parse-req subs))
     (define resp (parse-resp subs))
     (cond [req
            (match-define (list (list req-method (list req-path req-query) ver)
                                req-head req-body) req)
            (match-define (list resp-stat resp-head resp-body) resp)
            (api-func name (string-join docs "")
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
    [(list-no-order (md-section 2
                                (or "Response" "Response:")
                                (list-no-order (md-code-block beg end code)
                                               _ ...))
                    _ ...)
     (call-parser parse-template-response code beg)]
    [else '(() () ())]))

;; Cqll the parser function `f` on the `code`, setting the port
;; location to `pos` so that error reporting will be for the the
;; containing file from which we got the code. Also uses the
;; `current-source` parameter which is the name of teh source file.
(define/contract (call-parser f code pos)
  (procedure? bytes? position? . -> . any)
  (define in (open-input-bytes code))
  (port-count-lines! in)
  (set-port-next-location! in
                           (position-line pos)
                           (position-col pos)
                           (position-offset pos))
  (f (current-source) in))

;; test
;; (wffi-lib "examples/horseebooks.md")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Return a string with documentation for the API function, in
;; markdown format.  Not hard, since we kept the original markdown
;; fragments.
(define/contract (api-func->markdown x)
  (api-func? . -> . string?)
  (string-append "# " (api-func-name x) "\n"
                 "\n"
                 (api-func-desc x) "\n"
                 ))

;; Return documentation for the API, in Scribble format.
(define/contract (api-func->scribble a)
  (api-func? . -> . any/c)
  (error 'api-func->scribble "TO-DO")
  "")
