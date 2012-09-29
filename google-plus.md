# Get person

Get a person's profile.

If using the userId value "me", this method requires authentication
using a token that has been granted the OAuth scope
https://www.googleapis.com/auth/plus.me. Read more about
[OAuth](https://developers.google.com/+/api/oauth.html).

## Request:

````
GET /plus/v1/people/{userId}?key={key} HTTP/1.0
````
