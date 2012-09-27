#lang racket

(require net/uri-codec
         "api.rkt"
         "grammar.rkt"
         "split.rkt"
         "dict-merge.rkt")
         
(provide make-api-keyword-procedure
         apply-dict
         wffi-lib
         get-wffi-obj
         get-wffi-obj/client-dict-proc
         get-wffi-obj/client-keyword-proc
         )

(define (dict->request a d)
  ;; (api? dict? . -> . string?)
  (define-values (m p q h b) (request-parts (api-req a)))
  (define path (string-join (for/list ([x p])
                              (cond [(string? x) x]
                                    [(symbol? x) (dict-ref d x)]
                                    [else (error 'dict->request)]))
                            ""))
  (define query (alist->form-urlencoded
                 (for/list ([x q])
                   (match x
                     [(list k v) (cons k (format "~a" (dict-ref d k v)))]
                     [(var k) (cons k (format "~a" (dict-ref d x)))]))))
  (define method+path+query
    (string-append (string-upcase (symbol->string m))
                   " "
                   path
                   (cond [(string=? "" query) ""]
                         [else (string-append "?" query)])))
  (define head
    (for/list ([x h])
      (match x
        [(list k v) (cons k (format "~a" (dict-ref d k v)))]
        [(var k) (cons k (format "~a" (dict-ref d x)))])))
  (define body (alist->form-urlencoded
                (for/list ([x b])
                  (match x
                    [(list k v) (cons k (format "~a" (dict-ref d k v)))]
                    [(var k) (cons k (format "~a" (dict-ref d x)))]))))
  (values method+path+query head body))

(define ex
  (api-grammar->api-struct
   '("Example POST API"
     "doc string"
     (post ("/user/" user "/items/")
           (qa qb)
           (Authorization
            [Content-Type "application/x-www-form-urlencoded"]
            Content-Length)
           (a b))
     (() () ()))))

(dict->request ex (hash 'user "Greg"
                        'qa "qa"
                        'qb "qb"
                        'Host "foobar.com"
                        'Authorization "blah"
                        ;'Content-Type "OVERRIDE DEFAULT!!!"
                        'Content-Length 10
                        'a "a"
                        'b "b"))

;; Client: From an HTTP response that has already been matched with a
;; api?, fill a dict? with all of the parameterized values.
(define/contract (response->dict a str)
  (api? string? . -> . dict?)
  (define-values (s h e) (split-response str))
  (dict-merge
   (match s
     [(pregexp "^HTTP/(\\d\\.\\d) (\\d{3}) (.*)$" (list _ ver code text))
      (hash 'HTTP-Ver ver
            'HTTP-Code code
            'HTTP-Text text)])
   (for/hash ([x (regexp-split #rx"\r|\n|\r\n" h)])
     (match x [(pregexp "^(.+?)\\s*:\\s*(.+?)$" (list _ k v))
               (values (string->symbol k) v)]))
   (cond [(regexp-match?
           #px"Content-Type\\s*:\\s*application/x-www-form-urlencoded"
           h)
          (for/hash ([x (regexp-split #rx"&" e)] #:when (not (string=? "" x)))
            (match x [(pregexp "^(.+?)=(.+?)$" (list _ k v))
                      (values (string->symbol k) v)]))]
         [else (hash)])))

(response->dict ex
                #<<--
HTTP/1.1 200 OK
Date: today
Content-Type: application/x-www-form-urlencoded
Content-Length: 7

a=1&b=2
--
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (syms xs)
  (for/list ([x xs])
    (match x
      [(list k v) k]
      [(var x) x])))

(define (symbol<=? a b)
  (string<=? (symbol->string a) (symbol->string b)))

(define/contract (api-inputs a)
  (api? . -> . (listof symbol?))
  (define-values (m p q h b) (request-parts (api-req a)))
  (sort (append (for/list ([x p]
                           #:when (symbol? x))
                  x)
                (syms q)
                (syms h)
                (syms b))
        symbol<=?))

;;(api-inputs ex)

(define (api-outputs a)
  (define-values (s h b) (response-parts (api-resp a)))
  (sort (append (syms s)
                (syms h)
                (syms b))
        symbol<=?))

;;(api-outputs ex)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; for use by client

(define (do-request a d connect)
  (define req-str (dict->request a d))
  (log-debug req-str)
  (define-values (in out) (connect (dict-ref d 'host)))
  (display req-str out)
  (flush-output out)
  (define resp-str (port->string in))
  (log-debug resp-str)
  (begin0
      (response->dict a resp-str)
    (close-input-port in)
    (close-output-port out)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define symbol->keyword (compose1 string->keyword symbol->string))
(define keyword->symbol (compose1 string->symbol keyword->string))

(define (make-api-dict-procedure a connect)
  (lambda (d)
    (do-request a d connect)))

;; Instead of a function that takes a dict, a function that takes
;; keyword arguments.
(define (make-api-keyword-procedure a connect)
  (define f (make-keyword-procedure
             (lambda (kws vs . rest)
               (do-request a
                           (map cons
                                (map keyword->symbol kws)
                                vs)
                           connect))))
  (define kws (map string->keyword
                   (sort (map symbol->string
                              (api-inputs a))
                         string<?)))
  (procedure-reduce-keyword-arity f 0 kws kws))

;; Given a function taking solely keyword arguments, and a dictionary
;; of symbol? => any/c, do a keyword-apply treating the dictionary
;; keys as keywords.
(define (apply-dict f d)
  (define xs (sort (for/list ([(k v) (in-dict d)])
                     (cons (symbol->keyword k) v))
                   keyword<?
                   #:key car))
  (define kws (map car xs))
  (define vs (map cdr xs))
  (keyword-apply f kws vs (list)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define/contract (wffi-lib s)
  (path-string? . -> . (listof api?))
  (error))
  ;; (markdown->apis (file->string s)))

(define/contract (get-wffi-obj lib name)
  ((listof api?) string? . -> . api?)
  (define a (findf (lambda (x) (string=? name (api-name x))) lib))
  (cond [a a]
        [else (error 'wffi-define "can't find ~s" name)]))

(define/contract (get-wffi-obj/client-dict-proc lib name connect)
  ((listof api?) string? (string? . -> . (values input-port? output-port?))
   . -> . procedure?)
  (make-api-dict-procedure (get-wffi-obj lib name) connect))

(define/contract (get-wffi-obj/client-keyword-proc lib name connect)
  ((listof api?) string? (string? . -> . (values input-port? output-port?))
   . -> . procedure?)
  (make-api-keyword-procedure (get-wffi-obj lib name) connect))

;; (define as (markdown->apis (file->string "example.md")))
;; as

;; (define f (make-api-keyword-procedure (first as)))
