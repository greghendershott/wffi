#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc
         "key-value.rkt"
         )

(provide parse-template-request)

(define-tokens data (DATUM WS CRLF ENTITY))
(define-empty-tokens delim (EQ COLON
                               OPEN-BRACE CLOSE-BRACE
                               OPEN-BRACKET CLOSE-BRACKET
                               QUESTION AMPERSAND
                               EOF))

(define template-request-lexer
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
   ;; Allow "line-joining" using indenting on following line:
   [(:: #\newline (:+ #\space))
    (return-without-pos (template-request-lexer input-port))]
   [whitespace (token-WS lexeme)]
   ;; In the following, it seems necessary to duplicate the list
   ;; above, in a ~ expression. Really???
   [(:+ (:~ (:or #\= #\:
                 #\{ #\}
                 #\[ #\]
                 #\? #\&
                 whitespace)))
    (token-DATUM lexeme)]
   [(eof) 'EOF]
   ))

(define template-request-parser
  (parser
   (start request)
   (end EOF)
   (src-pos)
   (error (lambda (tok-ok? tok-name tok-value start end)
            (error 'template-response-parser
                   "Unexpected ~a at ~a:~a .. ~a:~a"
                   (or tok-value tok-name)
                   (position-line start)
                   (position-col start)
                   (position-line end)
                   (position-col end))))
   (tokens data delim)
   
   (grammar

    (value [(variable) $1]
           [(constant) $1])

    (variable
     [(OPEN-BRACE DATUM CLOSE-BRACE) (variable (string->symbol $2))]
     [(OPEN-BRACE CLOSE-BRACE) (variable #f)])

    (constant [(DATUM) (constant $1)])
    
    (request [(start-line heads body) (list $1 $2 $3)]
             [(start-line heads) (list $1 $2 '())])

    (start-line
     [(method WS path+query WS http-ver CRLF) (list $1 $3 $5)]
     [(method WS path+query CRLF) (list $1 $3 "HTTP/1.0")])
    
    (method [(DATUM) (string->symbol $1)])

    (path+query [(path) (list $1 '())]
                [(path QUESTION queries) (cons $1 (list $3))])

    (path [(path-parts-list) (reverse $1)])

    (path-parts-list [() null]
                     [(path-parts-list path-part) (cons $2 $1)])

    (path-part [(DATUM) $1]
               [(OPEN-BRACE DATUM CLOSE-BRACE)
                (variable (string->symbol $2))])

    (http-ver [(DATUM) $1])

    (queries [() null]
             [(queries query) (cons $2 $1)])

    (query [(DATUM EQ value) (->keyval $1 $3)]
           [(AMPERSAND query) $2]
           [(OPEN-BRACKET query CLOSE-BRACKET) (optional $2)])

    (heads [() '()]
           [(heads head) (cons $2 $1)])

    (head
     [(DATUM COLON) (->keyval $1 (constant ""))]
     [(DATUM COLON WS head-value) (->keyval $1 (constant $4))]
     [(DATUM COLON WS variable) (->keyval $1 $4)]
     [(head WS) $1]
     ;; We won't get a CRLF token for the final head because the lexer
     ;; will consume that into the ENTITY token.
     [(head CRLF) $1]
     [(OPEN-BRACKET head CLOSE-BRACKET) (optional $2)])

    ;; Constant header values may contain spaces
    (head-value [(head-value-list) (apply string-append (reverse $1))])
    (head-value-token [(DATUM) $1]
                      [(WS) $1])
    (head-value-list [() '()]
                     [(head-value-list head-value-token) (cons $2 $1)])
    
    (body [(ENTITY) (substring $1 2)])

    )))

(define (->keyval datum value)
  (keyval (string->symbol datum)
          (match value
            [(variable #f) (variable (string->symbol datum))]
            [else value])))

(define (parse-template-request in)
  (port-count-lines! in)
  (template-request-parser (lambda () (template-request-lexer in))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; example

#;
(define str #<<--
GET /users/{user}/items/{item}?a={}&[b=2] HTTP/1.1
Date: {}
Header: Constant value with whitespace
Authorization: {}
Aliased: {optional-alias}
[OptLit: default value]
[OptVar: {}]
EmptyHeader:
ValueWithTrailingWhitespace: SpaceBeforeLF-> 
Foo: Bar

This is the body line 1.
Here is line 2.
Notice that tokens like :, &, ? are treated as normal chars here.

--
)

#;
(let ([in (open-input-string str)])
  (displayln "LEXER============")
  (define f (lambda () (template-request-lexer in)))
  (let loop ()
    (define pt (f))
    (define t (position-token-token pt))
    (pretty-print t)
    (unless (eq? 'EOF t)
      (loop))))

#;
(let ([in (open-input-string str)])
  (displayln "PARSER==========")
  (port-count-lines! in)
  (template-request-parser (lambda () (template-request-lexer in))))
