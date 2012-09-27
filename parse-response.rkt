#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc
         )

(provide parse-template-response)

(define-tokens data (DATUM WS CRLF ENTITY))
(define-empty-tokens delims (EQ COLON
                                OPEN-BRACE CLOSE-BRACE
                                OPEN-BRACKET CLOSE-BRACKET
                                QUESTION AMPERSAND
                                EOF))

(define template-response-lexer
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
                 #\? #\&
                 whitespace)))
    (token-DATUM lexeme)]
   [(eof) 'EOF]
   ))

(define template-response-parser
  (parser
   (start response)
   (end EOF)
   (src-pos)
   (error (lambda (tok-ok? tok-name tok-value start end)
            (error 'request-parser
                   "tok-ok?= ~a. ~a is ~a at ~a:~a"
                   tok-ok? tok-name tok-value
                   (position-line start)
                   (position-col start))))   
   (tokens data delims)
   
   (grammar

    (value [(variable) $1]
           [(constant) $1])

    (variable
     [(OPEN-BRACE DATUM CLOSE-BRACE) (list 'VARIABLE (string->symbol $2))]
     [(OPEN-BRACE CLOSE-BRACE) (list 'VARIABLE)])

    (constant [(DATUM) (list 'CONSTANT $1)])
    
    (response [(start-line heads body) (list $1 $2 $3)]
              [(start-line heads) (list $1 $2 '())])

    (start-line [(http-ver WS code CRLF) (list $1 $3 "")]
                [(http-ver WS code WS desc CRLF) (list $1 $3 $5)])
    
    (http-ver [(DATUM) $1])

    (code [(DATUM) $1])

    (desc [(desc-list) (apply string-append (reverse $1))])
    (desc-token [(DATUM) $1]
                [(WS) $1])
    (desc-list [() '()]
               [(desc-list desc-token) (cons $2 $1)])

    (heads [() '()]
           [(heads head) (cons $2 $1)])

    ;; We won't get a CRLF token for the final head because the lexer
    ;; will consume that into the ENTITY token.
    (head
     [(DATUM COLON) (list (string->symbol $1) (list 'CONSTANT ""))]
     [(DATUM COLON WS head-value) (list (string->symbol $1) (list 'CONSTANT $4))]
     [(DATUM COLON WS variable) (var-name $1 $4)]
     [(head WS) $1]
     [(head CRLF) $1]
     [(OPEN-BRACKET head CLOSE-BRACKET) (list 'OPTIONAL $2)])

    ;; Constant header values may contain spaces
    (head-value [(head-value-list) (apply string-append (reverse $1))])
    (head-value-token [(DATUM) $1]
                      [(WS) $1])
    (head-value-list [() '()]
                     [(head-value-list head-value-token) (cons $2 $1)])

    (body [(ENTITY) (substring $1 2)])

    )))

(define (var-name datum value)
  (list (string->symbol datum) (match value
                                 [(list 'VARIABLE)
                                  (list 'VARIABLE (string->symbol datum))]
                                 [else value])))

(define (parse-template-response s)
  (define in (open-input-string s))
  (template-response-parser (lambda () (template-response-lexer in))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; example

#;
(define str #<<--
HTTP/1.1 404 Not Found
Date: Today
EmptyHeader:
Header1: {}
Header2: {Alias}
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
  (define f (lambda () (template-response-lexer in)))
  (let loop ()
    (define pt (f))
    (define t (position-token-token pt))
    (pretty-print t)
    (unless (eq? t 'EOF)
      (loop))))

#;
(let ([in (open-input-string str)])
  (displayln "PARSER==========")
  (template-response-parser (lambda () (template-response-lexer in))))
