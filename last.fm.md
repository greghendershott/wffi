# last.fm

See <http://www.last.fm/api/intro>.

This file defines only _anonymous_ services.

# Chart

Get various things from the chart.

## Request:

````
GET /2.0/
    ?method={}
    &api_key={api-key}
    &format=json
    &[page=1]
    &[limit=50]
````

 `method` can be:
- `chart.getHypedArtists`
- `chart.getHypedTracks`
- `chart.getLovedTracks`
- `chart.getTopArtists`
- `chart.getTopTags`
- `chart.getTopTracks`

