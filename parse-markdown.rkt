#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc)

(define-tokens data (DATUM WS))
(define-empty-tokens delim (POUND TILDE LF EOF))

(define markdown-lexer
  (lexer-src-pos
   [#\# 'POUND]
   [#\newline 'LF]
   [#\~ 'TILDE]
   [whitespace (token-WS lexeme)]
   [(:+ (:~ (:or #\# #\newline #\~ whitespace))) (token-DATUM lexeme)]
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

   (grammar

    (markdown-file [(sections) $1])

    (sections [(section-list) (reverse $1)])
    (section-list [() '()]
                  [(section-list section) (cons $2 $1)])
    (section [(pounds WS title LF content) (list $1 $3 $5)])

    (pounds [(pounds-list) (list 'level (length $1))])
    (pounds-list [() '()]
                 [(pounds-list POUND) (cons #\# $1)])

    (content [(content-list) (reverse $1)])
    (content-list [() '()]
                  [(content-list content-part) (cons $2 $1)])
    (content-part [(plain-content) $1]
                  [(code-block) $1])

    (plain-content [(plain-content-list LF) (reverse/str $1)])
    (plain-content-list [() '()]
                        [(plain-content-list plain-content-token) (cons $2 $1)])
    (plain-content-token [(DATUM) $1]
                         [(WS) $1]
                         [(LF) "\n"]
                         [(TILDE) "~"]
                         ;;[(POUND) "#"]
                         )

    (code-block [(four-tilde-lf code-block-content four-tilde-lf)
                 (list 'code-block $2)])
    (four-tilde-lf [(TILDE TILDE TILDE TILDE LF) 'four-tilde-lf])
    (code-block-content [(code-block-content-list) (reverse/str $1)])
    (code-block-content-list [() '()]
                             [(code-block-content-list code-block-token) (cons $2 $1)])
    (code-block-token [(DATUM) $1]
                      [(WS) $1]
                      [(LF) "\n"]
                      ;;[(TILDE) "~"]
                      )
    
    (title [(title-list) (reverse/str $1)])
    (title-list [() '()]
                [(title-list title-token) (cons $2 $1)])
    (title-token [(DATUM) $1]
                 [(WS) $1])
    )))

(define (reverse/str xs)
  (apply string-append (reverse xs)))

(define str
#<<--
# Intro
Some stuff. This should be ignored.
## Request
Here's some code:
~~~~
SOME CODE
HERE.
~~~~
Postfix.
## Response
More content.
### Level 3
Level 3 content.
#### Level 4

--
)

#;
(let ([in (open-input-string str)])
  (displayln "LEXER============")
  (define f (lambda () (markdown-lexer in)))
  (let loop ()
    (define pt (f))
    (define t (position-token-token pt))
    (pretty-print t)
    (unless (eq? 'EOF t)
      (loop))))

(let ([in (open-input-string str)])
  (displayln "PARSER==========")
  (port-count-lines! in)
  (markdown-parser (lambda () (markdown-lexer in))))
