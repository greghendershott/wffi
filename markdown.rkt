#lang racket

(require "api.rkt"
         "grammar.rkt"
         "split.rkt")

;; markdown -> grammar

(define/contract (markdown->grammar md)
  (string? . -> . api-grammar?)
  (error))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Markdown parsing
;;
;; Note: I suck at parsers. This is ad-hoc, fragile, bad at error-reporting.

;; Pregexp for one section of documentation:
(define px-api (pregexp (string-append "^"
                                       "# (.+?)\n+" ;name
                                       "(.+?)\n+"   ;desc
                                       "## (?i:Request):\\s*\n+"
                                       "(.+?)\n*"   ;req
                                       "## (?i:Response):\\s*\n+"
                                       "(.+?)\n*"   ;resp
                                       "$"
                                       )))

(define/contract (markdown->apis s)
  (string? . -> . (listof api?))
  (for/list ([x (in-list (get-sections s))])
    (api-grammar->api-struct (markdown->grammar (get-subsections x)))))

(define (get-sections s)
  (let loop ([xs (map car (regexp-match-positions* #rx"(?m:^# .+?\n)" s))])
    (cond
     [(empty? xs) (list)]
     [(empty? (cdr xs)) (cons (substring s (car xs)) (loop (cdr xs)))]
     [else (cons (substring s (car xs) (cadr xs)) (loop (cdr xs)))])))

(define (get-subsections s)
  (match s
    [(pregexp px-api (list _ name desc req resp))
     (list name desc (clean req) (clean resp))]
    [else #f]))

(define (kill-leading-spaces s)
  (string-join (for/list ([s (in-list (regexp-split "\n" s))])
                 (regexp-replace #px"^\\s+" s ""))
               "\n"))
(define (join-query-params s)
  (regexp-replace* "\n[?&]" s "\\&"))

(define (ensure-double-newline s)
  (cond [(regexp-match? #px"\n{2}" s) s]
        [else (string-append s "\n")]))

(define clean
  (compose1 ensure-double-newline
            join-query-params
            kill-leading-spaces
            ))

;;(kill-leading-spaces "\n  adfasdf\n asdfasdfds")
;;(join-query-params "fooo\n&bar\n&foo")
;;(ensure-double-newline-ending "adsfadsf\n\nasdfasdf\n")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; markdown

;; Return a string with documentation for the API, in markdown format.
(define/contract (api->markdown x)
  (api? . -> . string?)
  (string-append
   (header1 (api-name x))
   (api-desc x) "\n"
   "\n"
   (header2 "Request")
   (block-indent (api-req x)) "\n"
   "\n"
   (header2 "Response")
   (block-indent (api-resp x)) "\n"
   "\n"
   ))

(define (header s c)
  (string-append s "\n"
                 (make-string (string-length s) c) "\n"
                 "\n"))

(define (header1 s)
  (header s #\=))

(define (header2 s)
  (header s #\-))

(define (block-indent s)
  (string-append "    "
                 (string-join (regexp-split "\n" s)
                              "\n    ")))
                              
;; Return a string with documentation for the API, in Scribble format.
(define/contract (api->scribble x)
  (api? . -> . string?)
  "")                                   ;TO-DO

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; `f' is called so that it may add some values to the dict (they
;; don't need to be the original values passed to it) and return the
;; new dict. If it doesn't want to add any values at all, it can
;; simply return the original dict.
(define/contract (k/v-string->dict str sep eq-delim curly-val? f)
  (string? string? string? boolean? (dict? string? string? . -> . dict?)
           . -> . dict?)
  (define px (pregexp (string-append "^"
                                     "\\[?"
                                     "(\\S+?)\\s*"
                                     (regexp-quote eq-delim)
                                     "\\s*"
                                     (if curly-val? "\\{" "")
                                     "(.+?)"
                                     (if curly-val? "\\}" "")
                                     "\\]?"
                                     "[\r\n]*"
                                     "$")))
  (for/fold ([d '()]) ;use an alist instead of hash; few items
            ([x (in-list (regexp-split (regexp-quote sep) str))])
    (define optional? (match x
                        [(pregexp "^\\[.+\\]$") #t]
                        [else #f]))
    (when optional? (printf "optional: ~s\n" x))
    (match (regexp-match px x)
      [(list _ k v) (f d k v)]
      [else #|(printf "ignoring ~s from ~s\n" x str)|# d])))

(define/contract (string->dict str sep eq-delim)
  (string? string? string? . -> . dict?)
  (k/v-string->dict str sep eq-delim #t
                    (lambda (d k v)
                      (dict-set d k (string->symbol v)))))

