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

(define request-lexer
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
   ;;[whitespace (request-lexer input-port)] ;recursive call skips whitesapce
   ;; In the following, it seems necessary to duplicate the list above in
   ;; a ~ expression. Really???
   [(:+ (:~ (:or #\= #\: #\{ #\} #\[ #\] #\? #\& whitespace)))
    (token-ID lexeme)]
   [(eof) 'EOF]
   ))

(define str #<<--
GET /foo/bar HTTP/1.1
Date: Today
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
   (start request)
   (end EOF)
   (error (lambda (tok-ok? tok-name tok-value)
            (error 'request-parser
                   "tok-ok?= ~a. ~a is ~a"
                   tok-ok? tok-name tok-value)))
   (tokens A B)
   ;;(precs (left))
   
   (grammar

    (request [(start-line heads body)
              (list $1 $2 $3)])

    (start-line [(method WS path+query WS http-ver CRLF)
                 (list $1 $3 $5)])
    
    (method [(ID) $1])

    (path+query [(ID) (list $1 '())]
                [(ID QUESTION query-list) (cons $1 (list $3))])

    (http-ver [(ID) $1])

    (query-list [() null]
                [(query-list query) (cons $2 $1)])

    (query [(ID EQ ID) (cons-sym $1 $3)]
           [(AMPERSAND ID EQ ID) (cons-sym $2 $4)]
           )

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
  (define f (lex-this request-lexer in))
  (let loop ()
    (define t (f))
    (pretty-print t)
    (unless (eq? t 'EOF)
      (loop))))

(let ([in (open-input-string str)])
  (displayln "PARSER==========")
  (request-parser (lex-this request-lexer in)))

