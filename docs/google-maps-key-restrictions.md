# Google Maps key restrictions

Pet Taxi route estimation uses the `estimatePetTaxiRoute` callable function.
Its `GOOGLE_MAPS_SERVER_KEY` must be stored as a Firebase Secret and restricted
to the Directions API. It must not be copied into Flutter or web assets.

The key in `web/index.html` is a separate browser key for Maps JavaScript,
Places, and the JavaScript Geocoder. In Google Cloud Console, restrict it by
HTTP referrer to the deployed app origins (including local development), and
enable Maps JavaScript API, Places API, and Geocoding API for its project.
Do not use the server key for the JavaScript loader. If the JavaScript
Geocoder reports `REQUEST_DENIED`, check the referrer entries and API
restrictions on this browser key rather than weakening the restrictions.
