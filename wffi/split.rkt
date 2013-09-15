#lang racket

(provide split-request
         split-response
         )

(define/contract (split-request req)
  (string? . -> . (values string? string? string? string? string?))
  (match req
    [(pregexp "^(.+?)\\s+(.+?)\n(.+?)$" (list _ m p+q h+e))
     ;; I couldn't figure out the regexp to split p and q in the
     ;; first place, so split them now.
     (define-values (p q)
       (match (regexp-split (regexp-quote "?") p+q)
         [(list p q) (values p q)]
         [(list p) (values p "")]
         [(list) (values "" "")]
         [else (error 'split-request "can't determine path and query")]))
     ;; I couldn't figure out the regexp to split h and e in the
     ;; first place, so split them now.
     (define-values (h e)
       (match (regexp-split "\n\n" h+e)
         [(list h e) (values h e)]
         [(list h) (values h "")]
         [(list) (values "" "")]
         [else (error 'split-request
                      "can't determine heads and entity:\n~s" h+e)]))
     (values m p q h e)]
    [else (error 'split-request "can't parse request template")]))  

(define px (pregexp (string-append
                     "^"
                     "(.+?)" "(?:\r\n|\r|\n)"
                     "(.+?)" "(?:\r\n\r\n|\r\r|\n\n)"
                     "(.*?)"
                     "$")))
(define/contract (split-response resp)
  (string? . -> . (values string? string? string?))
  (match (regexp-match px resp)
    [(list _ s h e) (values s h e)]
    [else (error 'split-response "can't determine heads and entity ~s" resp)]))
