# Anonymous API

Source: <http://api.imgur.com/resources_anon>

The anonymous API lets you upload images, get site statistics, get
information on images, and read the images from the gallery. Anonymous
API users get 500 API credits per hour, which is equal to 50 uploads
per hour. If you don't want to upload images into your account, and
you're ok with the 50 uploads per hour limit, then the anonymous API
might be for you. All credits and limits are per ip address only and
are not associated with the API key.


# Stats

Display site statistics, such as bandwidth usage, images uploaded,
image views, and average image size.

## Request:

    GET /2/stats.json?[view={}]

### Comments

`view`: View the data during a certain time. Accepted values: `today`
(the past 24 hours), `week` (the past 7 days), `month` (the past 30ish
days - default).

## Response:

    HTTP/1.0 200 OK
    X-RateLimit-Limit: {}
    X-RateLimit-Remaining: {}

# Upload

Upload a file, including side-loading from a URL.

## Request:

    PUT /2/upload.json
      ?key={}
      &image={}
      &type={}
      &[name={}]
      &[title={}]
      &[caption={}]
    Content-Length: 0

## Response:

    HTTP/1.0 200 OK
    X-RateLimit-Limit: {}
    X-RateLimit-Remaining: {}

# Album

Returns album information and lists all images that belong to the album.

## Request:

    GET /2/album/{id}.json

## Response:
    
    HTTP/1.0 200 OK
    X-RateLimit-Limit: {}
    X-RateLimit-Remaining: {}

# Image

Returns all the information about a certain image

## Request:

    GET /2/image/{hash}.json

## Response:

     HTTP/1.0 200 OK

# Delete Image

Delete an image.

## Request:

    DELETE /2/delete/{hash}

## Response:

     HTTP/1.0 200 OK
