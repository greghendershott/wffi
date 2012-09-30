#lang racket

(require wffi/client
         json)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".google-api-key")])
  (match (file->string file #:mode 'text)
    [(regexp "^\\s*(.*?)\\s*(?:[\r\n]*)$" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr. Else raise an error.
(define (check-response who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200) (bytes->jsexpr (dict-ref d 'entity))]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TO-DO: Make paginated versions of these which take nextPageToken from the
;; response and supply it as &pageToken, until done.

(define endpoint (make-parameter "https://www.googleapis.com"))
(define lib (wffi-lib "google-plus.md"))
(define get-person (compose1 (lambda (x) (check-response 'get-person x))
                             (wffi-rest-proc lib "Get person" endpoint)))
(define search-people (compose1 (lambda (x) (check-response 'search-people x))
                                (wffi-rest-proc lib "Search people" endpoint)))
(define people-activity (compose1 (lambda (x) (check-response 'people-activity x))
                                  (wffi-rest-proc lib "People activity" endpoint)))
(define activity-list (compose1 (lambda (x) (check-response 'activity-list x))
                                (wffi-rest-proc lib "Activity list" endpoint)))

#;
(get-person 'key (api-key)
            'prettyPrint "false"
            'userId "107023078912536369392")
#;
(search-people 'key (api-key)
               'query "John McCarthy")
#;
(people-activity 'key (api-key))


(define (show-post-activity user-id)
  (define js
    (activity-list 'key (api-key)
                   'prettyPrint "false"
                   'userId user-id
                   'collection "public"))
  (define activities (dict-ref js 'items))
  (for/list ([a activities])
    (define activity-id (dict-ref a 'id))
    (define title (dict-ref a 'title))
    (define plus-oners (people-activity 'key (api-key)
                                        'activityId activity-id
                                        'collection "plusoners"))
    (define resharers (people-activity 'key (api-key)
                                       'activityId activity-id
                                       'collection "resharers"))
    (list activity-id
          title
          (length (dict-ref plus-oners 'items))
          (length (dict-ref resharers 'items)))))
;;(show-post-activity "107023078912536369392")
