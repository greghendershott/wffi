#lang racket

(require "api.rkt"
         "split.rkt"
         "parse-request.rkt"
         "parse-response.rkt"
         )

(provide wffi-lib
         wffi-obj
         markdown->apis
         api->markdown)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define/contract (wffi-lib s)
  (path-string? . -> . (listof api?))
  (markdown->apis (file->string s)))

(define/contract (wffi-obj lib name)
  ((listof api?) string? . -> . api?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (cond [a a]
        [else (error 'wffi-obj "can't find ~s" name)]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define/contract (markdown->apis s)
  (string? . -> . (listof api?))
  (filter-map section->api (sections s)))

(define/contract (sections s)
  (string? . -> . (listof string?))
  (let loop ([xs (map car (regexp-match-positions* #rx"(?m:^# .+?\n)" s))])
    (cond
     [(empty? xs) (list)]
     [(empty? (cdr xs)) (cons (substring s (car xs)) (loop (cdr xs)))]
     [else (cons (substring s (car xs) (cadr xs)) (loop (cdr xs)))])))

;; Pregexp for one section of a markdown file documenting one API.
(define px-api (pregexp (string-append "^"
                                       "# (.+?)\n+" ;name
                                       "(.*?)\n+"   ;desc
                                       "## (?i:Request):?\\s*\n"
                                       "````\n"
                                       "(.+?)"   ;req
                                       "````\n"
                                       "[^#]*?"
                                       "(?:"
                                         "## (?i:Response):?\\s*\n"
                                         "````\n"
                                         "(.*?)"   ;resp
                                         "````\n"
                                         ".*?"
                                       ")?"
                                       ".*?"
                                       "$"
                                       )))

(define/contract (section->api sec)
  (string? . -> . (or/c #f api?))
  (match sec
    [(pregexp px-api (list _ name doc req resp))
     (match-define (list (list req-method (list req-path req-query) http-ver)
                         req-head
                         req-body)
                   (parse-template-request (open-input-string (clean req))))
     (match-define (list resp-stat resp-head resp-body) 
                   (parse-template-response (open-input-string (clean resp))))
     (init-api name doc req resp
               req-method req-path req-query req-head resp-head)]
    [else #f]))

;; Kill leading spaces, including but not limted to 4 spaces for code
;; blocks.
(define (kill-leading-spaces s)
  (string-join (for/list ([s (in-list (regexp-split "\n" s))])
                 (regexp-replace #px"^\\s+" s ""))
               "\n"))

;; Allow query parameters to be split across multiple lines; here,
;; join to one line.
(define (join-query-params s)
  (regexp-replace* "\n([?&])" s "\\1"))

(define (end-with-newline s)
  (regexp-replace #rx"^(.+?)(\n*?)$" s "\\1\n"))

(define (ignore-subsubsections s)
  (regexp-replace #rx"(?:\n###).+$" s "\n"))

(define clean
  (compose1 end-with-newline
            join-query-params
            kill-leading-spaces
            ignore-subsubsections
            (lambda (s) (or s ""))
            ))

;; (end-with-newline "abc\n123")
;; (end-with-newline "abc\n123\n")
;; (end-with-newline "abc\n123\n\n")
;; (end-with-newline "abc\n123\n\n\n")
;; (ignore-subsubsections "abc\n### yo yo\n\n")
;; (end-with-newline (ignore-subsubsections "abc\n123\n\n\n"))
;; (kill-leading-spaces "\n  adfasdf\n asdfasdfds")
;; (join-query-params "fooo\n&bar\n&foo")

;; ;; test
;; (define as (markdown->apis (file->string "imgur.md")))
;; as

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; markdown

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
