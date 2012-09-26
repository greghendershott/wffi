#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc
         )

(define-tokens A (ID WS CRLF ENTITY))
(define-empty-tokens B (EQ COLON
                        ;; OPEN-BRACE CLOSE-BRACE
                        ;; OPEN-BRACKET CLOSE-BRACKET
                        QUESTION AMPERSAND
                        EOF))

(define response-lexer
  (lexer
   [#\= 'EQ]
   [#\: 'COLON]
   ;; [#\{ 'OPEN-BRACE]
   ;; [#\} 'CLOSE-BRACE]
   ;; [#\[ 'OPEN-BRACKET]
   ;; [#\] 'CLOSE-BRACKET]
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
   [(:+ (:~ (:or #\= #\: #\{ #\} #\[ #\] #\? #\& whitespace)))
    (token-ID lexeme)]
   [(eof) 'EOF]
   ))

(define str #<<--
HTTP/1.1 404 Not Found
Date: Today
EmptyHeader:
ValueWithTrailingWhitespace: SpaceBeforeLF-> 
Foo: Bar

This is the body line 1.
Here is line 2.
Notice that tokens like :, &, ? are treated as normal chars here.

--
)

(define response-parser
  (parser
   (start response)
   (end EOF)
   (error (lambda (tok-ok? tok-name tok-value)
            (error 'response-parser
                   "tok-ok?= ~a. ~a is ~a"
                   tok-ok? tok-name tok-value)))
   (tokens A B)
   ;;(precs (left))
   
   (grammar

    (response [(start-line heads body)
              (list $1 $2 $3)])

    (start-line [(http-ver WS code CRLF) (list $1 $3 "")]
                [(http-ver WS code WS desc CRLF) (list $1 $3 $5)])
    
    (http-ver [(ID) $1])

    (code [(ID) $1])

    (desc [(desc-list) (apply string-append (reverse $1))])
    (desc-token [(ID) $1]
                [(WS) $1])
    (desc-list [() '()]
               [(desc-list desc-token) (cons $2 $1)])

    (heads [() '()]
           [(heads head) (cons $2 $1)])

    ;; We won't get a CRLF token for the final head because the lexer
    ;; will consume that into the ENTITY token.
    (head [(ID COLON CRLF) (cons-sym $1 "")] ;ending in CRLF
          [(ID COLON WS CRLF) (cons-sym $1 "")]
          [(ID COLON WS ID CRLF) (cons-sym $1 $4)]
          [(ID COLON WS ID WS CRLF) (cons-sym $1 $4)]
          [(ID COLON) (cons-sym $1 "")] ;NOT ending in CRLF
          [(ID COLON WS) (cons-sym $1 "")]
          [(ID COLON WS ID) (cons-sym $1 $4)]
          [(ID COLON WS ID WS) (cons-sym $1 $4)])

    (body [(ENTITY) (substring $1 2)])

    ;; (val-pair
    ;;  [(ID EQ ID) (list "default" $1 $3)]
    ;;  [(ID EQ OPEN-BRACE ID CLOSE-BRACE) (list "normal" $1 $4)]
    ;;  [(OPEN-BRACKET ID EQ OPEN-BRACE ID CLOSE-BRACE) (list "opt" $2 $5)])
    )))

(define (cons-sym k v)
  (cons (string->symbol k) v))

(define (lex-this lexer input) (lambda () (lexer input)))
(let ([in (open-input-string str)])
  (displayln "LEXER============")
  (define f (lex-this response-lexer in))
  (let loop ()
    (define t (f))
    (pretty-print t)
    (unless (eq? t 'EOF)
      (loop))))

(let ([in (open-input-string str)])
  (displayln "PARSER==========")
  (response-parser (lex-this response-lexer in)))

