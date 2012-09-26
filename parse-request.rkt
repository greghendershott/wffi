#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc
         syntax/readerr
         )

(define-tokens data (DATUM WS CRLF ENTITY))
(define-empty-tokens delim (EQ COLON
                               OPEN-BRACE CLOSE-BRACE
                               OPEN-BRACKET CLOSE-BRACKET
                               QUESTION AMPERSAND
                               EOF))

(define request-lexer
  (lexer-src-pos
   [#\= 'EQ]
   [#\: 'COLON]
   [#\{ 'OPEN-BRACE]
   [#\} 'CLOSE-BRACE]
   [#\[ 'OPEN-BRACKET]
   [#\] 'CLOSE-BRACKET]
   [#\? 'QUESTION]
   [#\& 'AMPERSAND]
   ;; A double newline marks the start of the entity
   [(:: (:or (:: #\newline #\newline)
             (:: #\return #\return)
             (:: #\return #\newline #\return #\newline))
        any-string)
    (token-ENTITY lexeme)]
   [(:or "#\\return#\\newline" #\return #\newline) (token-CRLF lexeme)]
   [whitespace (token-WS lexeme)]
   ;; In the following, it seems necessary to duplicate the list above in
   ;; a ~ expression. Really???
   [(:+ (:~ (:or #\= #\:
                 #\{ #\}
                 #\[ #\]
                 #\? #\& whitespace)))
    (token-DATUM lexeme)]
   [(eof) 'EOF]
   ))

(define str #<<--
GET /users/{user}/items/{item}?a={}&[b=2] HTTP/1.1
Date: {}
Header: Constant-Value
Authorization: {}
Alias: {alias}
[OptionalLiteral: default]
[OptionalVariable: {}]
EmptyHeader:
ValueWithTrailingWhitespace: SpaceBeforeLF-> 
Foo: Bar

This is the body line 1.
Here is line 2.
Notice that tokens like :, &, ? are treated as normal chars here.

--
)

(define request-parser
  (parser
   (src-pos)
   (start request)
   (end EOF)
   (error (lambda (tok-ok? tok-name tok-value start end)
            ;; (raise-read-error 
            ;;  "read-error"
            ;;  "UNKNOWN"
            ;;  (position-line start)
            ;;  (position-col start)
            ;;  (position-offset start)
            ;;  (- (position-offset end)
            ;;     (position-offset start)))
            (error 'request-parser
                   "tok-ok?= ~a. ~a is ~a at ~a:~a"
                   tok-ok? tok-name tok-value
                   (position-line start)
                   (position-col start))))
   (tokens data delim)
   ;;(precs (left))
   
   (grammar

    (value [(variable) $1]
           [(DATUM) (list 'CONSTANT $1)])

    (variable [(OPEN-BRACE DATUM CLOSE-BRACE)
               (list 'VARIABLE (string->symbol $2))]
              [(OPEN-BRACE CLOSE-BRACE) (list 'VARIABLE)])
    
    (request [(start-line heads body)
              (list $1 $2 $3)])

    (start-line [(method WS path+query WS http-ver CRLF)
                 (list $1 $3 $5)])
    
    (method [(DATUM) $1])

    (path+query [(path) (list $1 '())]
                [(path QUESTION queries) (cons $1 (list $3))])

    (path [(path-parts-list) (reverse $1)])

    (path-parts-list [() null]
                     [(path-parts-list path-part) (cons $2 $1)])

    (path-part [(DATUM) $1]
               [(OPEN-BRACE DATUM CLOSE-BRACE) (list 'VARIABLE $2)])

    (http-ver [(DATUM) $1])

    (queries [() null]
             [(queries query) (cons $2 $1)])

    (query [(DATUM EQ value)
            (match $3
              [(list 'VARIABLE) (cons-sym $1 (list 'VARIABLE $1))]
              [else (cons-sym $1 $3)])]
           [(AMPERSAND query) $2]
           [(OPEN-BRACKET query CLOSE-BRACKET) (list 'OPTIONAL $2)])

    (heads [() '()]
           [(heads head) (cons $2 $1)])

    ;; We won't get a CRLF token for the final head because the lexer
    ;; will consume that into the ENTITY token.
    (head [(DATUM COLON) (cons-sym $1 (list 'CONSTANT ""))]
          ;;[(DATUM COLON WS) (cons-sym $1 (list 'CONSTANT ""))]
          [(DATUM COLON WS value)
           (match $4
             [(list 'VARIABLE) (cons-sym $1 (list 'VARIABLE $1))]
             [else (cons-sym $1 $4)])]
          [(head WS) $1]
          [(head CRLF) $1]
          [(OPEN-BRACKET head CLOSE-BRACKET) (list 'OPTIONAL $2)])

    ;; ;; TO-DO Need a way to handle WS in header values.
    ;;
    ;; (head-values [(head-values-list) (reverse $1)])
    ;; (head-values-list [() '()]
    ;;                   [(head-values-list head-value) (cons $2 $1)])
    ;; (head-value [(value) $1]
    ;;             [(WS) $1])

    (body [(ENTITY) (substring $1 2)])

    )))

(define (cons-sym k v)
  (list (string->symbol k) v))

(define (lex-this lexer input) (lambda () (lexer input)))

(let ([in (open-input-string str)])
  (displayln "LEXER============")
  (define f (lex-this request-lexer in))
  (let loop ()
    (define pt (f))
    (define t (position-token-token pt))
    (pretty-print t)
    (unless (eq? 'EOF t)
      (loop))))

(let ([in (open-input-string str)])
  (displayln "PARSER==========")
  (port-count-lines! in)
  (request-parser (lex-this request-lexer in)))

