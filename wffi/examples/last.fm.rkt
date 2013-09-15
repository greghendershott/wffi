#lang racket

(require wffi/client)

(define (read-api-key [file (build-path (find-system-path 'home-dir)
                                        ".last.fm-api-key")])
  (match (file->string file #:mode 'text)
    [(pregexp "^\\s*API Key\\s*=\\s*(.*?)\\s*\n+?" (list _ k)) k]
    [else (error 'read-api-key "Bad format for ~a" file)]))
(define api-key (make-parameter (read-api-key)))

(define (add-common-parameters h)
  (hash-set* h
             'api-key (api-key)))

(wffi-define-all "last.fm.md" add-common-parameters check-response/json)

;; last.fm is not very RESTful: It exposes a very small number of
;; "objects" as HTTP resources, where a query parameter called
;; `method` is an OOP method (not HTTP method). For example, the
;; function `artst.getEvents` isn't an HTTP resource `artist/events`,
;; instead it consists of the `artist?method=getEvents`.  Here we just
;; expose that.
;; 
;; Instead, a slightly higher-level wrapper could make a function for
;; each distinct object-and-method: e.g. artist-get-events.


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
