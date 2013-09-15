#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc)

(provide parse-markdown
         (struct-out md-section-group)
         (struct-out md-section)
         (struct-out md-code-block))

;; Why use a lexer and parser on a markdown file -- couldn't some
;; clever regexps suffice?  Sure, but the main advatange is error
;; reporting. For errors in the markdown itself. But also for errors
;; in fragments that we extract (such as the request and response
;; templates) and give to another parser. We can use the position info
;; from the markdown file to set the port location when parsing the
;; portions. The resulting error messages will pinpoint the location
;; in the overall markdown file.

(struct md-section-group (self subsections)       #:transparent)
(struct md-section       (level title content)    #:transparent)
(struct md-code-block    (start-pos end-pos text) #:transparent)

(define-tokens data (DATUM WS CODEBLOCK SECTION1 SECTION2+))
(define-empty-tokens delim (LF EOF))

(define markdown-lexer
  (lexer-src-pos
   ;; Most robust to define sections as including the preceding
   ;; newline as well as the one or more # chars:
   [(:: #\newline (:+ #\#))
    (let ([n (string-length (substring lexeme 1))])
      (cond [(= 1 n) (token-SECTION1 1)]
            [else (token-SECTION2+ n)]))]
   ;; Of course that leaves the special case of a section at the exact
   ;; start of the entire file, which we handle here:
   [(::           (:+ #\#))
    (cond [(and (= 1 (position-line start-pos))
                (= 0 (position-col start-pos)))
           (let ([n (string-length lexeme)])
             (cond [(= 1 n) (token-SECTION1 1)]
                   [else (token-SECTION2+ n)]))]
          [else (token-DATUM lexeme)])]
   ;; For codeblocks, we want to save and return the exact position of
   ;; the code itself. That way, if this code is passed to another
   ;; parser, the position can be used with `set-port-next-location!`
   ;; for pinpoint error reporting.
   [(:: "````\n" (:* (:~ "`")) "````")
    (token-CODEBLOCK (md-code-block
                      ;; adjust start-pos to exclude leading ````\n
                      (position (+ (position-offset start-pos) 5)
                                (+ (position-line start-pos) 1)
                                0)
                      ;; adjust end-pos to exclude trailing ````
                      (position (- (position-offset end-pos) 4)
                                (- (position-line end-pos) 1)
                                0)
                      (cadr (regexp-match #"````\n(.*)````" lexeme))))]
   [#\newline 'LF]
   [whitespace (token-WS lexeme)]
   [(:+ (:~ (:or #\newline #\~ whitespace))) (token-DATUM lexeme)]
   [(eof) 'EOF]
   ))

(define markdown-parser
  (parser
   (start markdown-file)
   (end EOF)
   (src-pos)
   (error (lambda (tok-ok? tok-name tok-value start end)
            (error 'markdown-parser
                   "Unexpected ~a at ~a:~a .. ~a:~a"
                   (or tok-value tok-name)
                   (position-line start)
                   (position-col start)
                   (position-line end)
                   (position-col end))))
   (tokens data delim)
   (suppress)

   (grammar

    (markdown-file [(grouped-sections) $1])

    (grouped-sections [(grouped-section-list) (reverse $1)])
    (grouped-section-list [() '()]
                          [(grouped-section-list grouped-section) (cons $2 $1)])
    (grouped-section [(section1 sections2+) (md-section-group $1 $2)])

    (sections2+ [(sections2+-list) (reverse $1)])
    (sections2+-list [() '()]
                     [(sections2+-list section2+) (cons $2 $1)])

    (section1 [(SECTION1 WS title LF content) (md-section $1 $3 $5)]
              [(SECTION1 WS title)            (md-section $1 $3 '(""))])
    (section2+ [(SECTION2+ WS title LF content) (md-section $1 $3 $5)]
               [(SECTION2+ WS title)            (md-section $1 $3 '(""))])

    (content [(content-list) (reverse $1)])
    (content-list [() '()]
                  [(content-list content-part) (cons $2 $1)])
    (content-part [(plain-content) $1]
                  [(CODEBLOCK) $1])

    (plain-content [(plain-content-list) (reverse/str $1)])
    (plain-content-list [() '()]
                        [(plain-content-list plain-content-token) (cons $2 $1)])
    (plain-content-token [(DATUM) $1]
                         [(WS) $1]
                         [(LF) "\n"])

    (title [(title-list) (reverse/str $1)])
    (title-list [() '()]
                [(title-list title-token) (cons $2 $1)])
    (title-token [(DATUM) $1]
                 [(WS) $1])
    )))

(define (reverse/str xs)
  (apply string-append (reverse xs)))

(define (lex-markdown in)
  (port-count-lines! in)
  (define f (lambda () (markdown-lexer in)))
  (let loop ()
    (define pt (f))
    (define t (position-token-token pt))
    (cond [(eq? 'EOF t) '()]
          [else (cons t (loop))])))

(define (parse-markdown in)
  (port-count-lines! in)
  (markdown-parser (lambda () (markdown-lexer in))))

#|

(define str
#<<--
# Intro
Some stuff. This pound -- # -- should be treated as literal.

## Some more documentation as a subsection.

Blah blah.

## Request

````
SOME CODE
HERE.
````

## Response
````
Another code block.
````
### Level 3
Level 3 content.
#### Level 4

--
)

#;
(let ([in (open-input-string str)])
  (lex-markdown in))
#;
(let ([in (open-input-string str)])
  (parse-markdown in))

#;
(call-with-input-file "imgur.md" parse-markdown)
#;
(call-with-input-file "google-plus.md" parse-markdown)
#;
(call-with-input-file "test.md" parse-markdown)
#;
(call-with-input-file "example.md" parse-markdown)

|#

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(module+ test
  (require rackunit)
  (define str
#<<--
# Intro
Some stuff. This pound -- # -- should be treated as literal.

## Some more documentation as a subsection.

Blah blah.

## Request

````
SOME CODE
HERE.
````

## Response
````
Another code block.
````
### Level 3
Level 3 content.
#### Level 4

--
)

  (check-true
   (match (parse-markdown (open-input-string str))
     [(list
       (md-section-group
        (md-section
         1
         "Intro"
         '("Some stuff. This pound -- # -- should be treated as literal.\n"))
        (list
         (md-section
          2
          "Some more documentation as a subsection."
          '("\nBlah blah.\n"))
         (md-section
          2
          "Request"
          (list
           "\n"
           (md-code-block (position 145 11 0)
                          (position 161 12 0)
                          '(#"SOME CODE\nHERE.\n"))
           "\n"))
         (md-section
          2
          "Response"
          (list (md-code-block (position 184 17 0)
                               (position 204 17 0)
                               '(#"Another code block.\n"))))
         (md-section 3 "Level 3" '("Level 3 content."))
         (md-section 4 "Level 4" '()))))
      #t]
     [else #f])))
