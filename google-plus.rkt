#lang racket

(require wffi/client
         json)

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".google-api-key")])
  (match (file->string file #:mode 'text)
    [(regexp "^\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr (this is extremely Google+
;; specific, not a role model for how to deal with other web services)
;; else raise an error.
(define (check-response who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200) (bytes->jsexpr (dict-ref d 'entity))]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))

(define (add-common-parameters h)
  (hash-set* h
             'key (api-key)
             'pretty-print "false"))

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

;; TO-DO: Make paginated versions of these which take nextPageToken from the
;; response and supply it as &pageToken, until done.

(define endpoint (make-parameter "https://www.googleapis.com"))
(define lib (wffi-lib "google-plus.md"))

(define (make-proc name who)
  (compose1 (lambda (x) (check-response who x))
            (wffi-dict-proc lib name endpoint)
            add-common-parameters
            hash))

(define-syntax-rule (defproc name api-name)
  (begin (define name (make-proc api-name #'name))
         (provide name)))

(defproc get-person "Get person")
(defproc search-people "Search people")
(defproc people-activity "People activity")
(defproc activity-list "Activity list")

;; examples:

#;
(get-person 'userId "107023078912536369392")
#;
(search-people 'query "John McCarthy")

(define (show-post-activity user-id)
  (define js
    (activity-list 'userId user-id
                   'collection "public"))
  (define activities (dict-ref js 'items))
  (for/list ([a activities])
    (define activity-id (dict-ref a 'id))
    (define title (dict-ref a 'title))
    (define plus-oners (people-activity 'activityId activity-id
                                        'collection "plusoners"))
    (define resharers (people-activity 'activityId activity-id
                                       'collection "resharers"))
    (list activity-id
          title
          (length (dict-ref plus-oners 'items))
          (length (dict-ref resharers 'items)))))
#;
(show-post-activity "107023078912536369392")
