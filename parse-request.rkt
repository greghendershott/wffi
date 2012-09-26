#lang racket

(require parser-tools/lex
         (prefix-in : parser-tools/lex-sre)
         parser-tools/yacc
         )

(define-tokens A (ID WS CRLF))
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
GET /foo/bar?a=1&b=2&c=3 HTTP/1.1
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

    (request [(start-line CRLF heads CRLF body)
              (list $1 $3 $5)])

    (start-line [(method WS path+query WS http-ver)
                 (list $1 $3 $5)])
    
    (method [(ID) $1])

    (path+query [(ID) (cons $1 (list #f))]
                [(ID QUESTION query-list) (cons $1 (list $3))])

    (http-ver [(ID) $1])

    (query-list [() null]
                [(query-list query) (cons $2 $1)])

    (query [(ID EQ ID) (cons $1 $3)]
           [(AMPERSAND ID EQ ID) (cons $2 $4)]
           )

    (heads [() '()]
           [(heads head) (cons $2 $1)])

    (head [(ID COLON CRLF) (cons $1 "")]
          [(ID COLON WS CRLF) (cons $1 "")]
          [(ID COLON WS ID CRLF) (cons $1 $4)]
          [(ID COLON WS ID WS CRLF) (cons $1 $4)])

    (body [(body-list) (apply string-append (reverse $1))])

    (body-token [(ID) $1]
                [(WS) $1]
                [(CRLF) $1]
                [(EQ) "="]
                [(COLON) ":"]
                ;; [(OPEN-BRACE) "{"]
                ;; [(CLOSE-BRACE) "}"]
                ;; [(OPEN-BRACKET) "["]
                ;; [(CLOSE-BRACKET) "]"]
                [(QUESTION) "?"]
                [(AMPERSAND) "&"])

    (body-list [() '()]
               [(body-list body-token) (cons $2 $1)])

    ;; (val-pair
    ;;  [(ID EQ ID) (list "default" $1 $3)]
    ;;  [(ID EQ OPEN-BRACE ID CLOSE-BRACE) (list "normal" $1 $4)]
    ;;  [(OPEN-BRACKET ID EQ OPEN-BRACE ID CLOSE-BRACE) (list "opt" $2 $5)])
    )))

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

