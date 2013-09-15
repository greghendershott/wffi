#lang racket

(require wffi/client)

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".google-api-key")])
  (match (file->string file #:mode 'text)
    [(regexp "^\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

(define (add-common-parameters h)
  (hash-set* h
             'key (api-key)
             'pretty-print "false"))

;; TO-DO: Make paginated versions of these which take nextPageToken from the
;; response and supply it as &pageToken, until done.

;; (define lib (wffi-lib "google-plus.md"))

;; (define (chain . fs)
;;   (apply compose1 (reverse fs)))

;; (define-syntax-rule (defproc name api-name)
;;   (begin (define name (chain hash
;;                              add-common-parameters
;;                              (wffi-dict-proc lib api-name)
;;                              (lambda (x) (check-response/json (syntax-e #'name) x))))
;;          (provide name)))

;; (defproc get-person "Get person")
;; (defproc search-people "Search people")
;; (defproc people-activity "People activity")
;; (defproc activity-list "Activity list")

(wffi-define-all "google-plus.md" add-common-parameters check-response/json)

;; examples:

#|

(get-person 'userId "107023078912536369392")

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
(show-post-activity "107023078912536369392")

|#
