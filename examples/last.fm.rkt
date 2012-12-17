#lang racket

(require wffi/client
         json)

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".last.fm-api-key")])
  (match (file->string file #:mode 'text)
    [(pregexp "^\\s*API Key\\s*=\\s*(.*?)\\s*\n+?" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

;; A helper to take the response dict and check the status code. If
;; 200, convert the bytes to a jsexpr. Else raise an error.
(define (check-response who d)
  (define code (dict-ref d 'HTTP-Code))
  (cond [(= code 200) (bytes->jsexpr (dict-ref d 'entity))]
        [else (error who "HTTP Status ~a ~s\n~a"
                     code (dict-ref d 'HTTP-Text) (dict-ref d 'entity))]))

(define (add-common-parameters h)
  (hash-set* h
             'api-key (api-key)))

;; When dealing with JSON, often need to do nested hash-refs. Analgesic:
(define (dict-refs d . ks)
  (for/fold ([d d])
            ([k ks])
    (dict-ref d k)))

(define lib (wffi-lib "last.fm.md"))

(define (chain . fs)
  (apply compose1 (reverse fs)))

(define-syntax-rule (defproc name api-name)
  (begin (define name (chain hash
                             add-common-parameters
                             (wffi-dict-proc lib api-name)
                             (lambda (x) (check-response (syntax-e #'name) x))))
         (provide name)))

;; last.fm exposes a small number of "objects", each at their own
;; resource, with a `method` query parameters. (As opposed to each
;; object-and-method being a distinct resource.)  Here we just expose
;; each "object". It might be a nicer interface if we made a wrapper
;; function for each distinct object-and-method, e.g. artist-events.

(defproc chart "Chart")
(defproc artist "Artist")
(defproc album "Album")
(defproc event "Event")
(defproc user "User")

;; Examples
#|
(chart 'method "chart.getHypedArtists"
       'limit 1)

(chart 'method "chart.getLovedTracks"
       'limit 1)

(artist 'method "artst.getEvents"
        'artist "Lady Gaga"
        'limit 1)

(artist 'method "artist.getTopTracks"
        'artist "Lady Gaga"
        'limit 5)

(let ([js (artist 'method "artist.getTopTracks"
                  'artist "Lady Gaga"
                  'limit 5)])
  (for/list ([x (dict-refs js 'toptracks 'track)])
    (list (dict-ref x 'name)
          (dict-ref x 'url))))

(album 'method "album.getInfo"
       'artist "Pink Floyd"
       'album "Dark Side of the Moon"
       'limit 1)

(event 'method "event.getInfo"
       'event 328799)

(user 'method "user.getInfo"
      'user "greghendershott")

;; Show recent tracks for a user
(struct track (name album artist) #:transparent)
(let ([js (user 'method "user.getRecentTracks"
                'user "greghendershott"
                'limit 25)])
  (define text (string->symbol "#text"))
  (for/list ([x (dict-refs js 'recenttracks 'track)])
    (track (dict-refs x 'name)
           (dict-refs x 'album text)
           (dict-refs x 'artist text))))
|#
