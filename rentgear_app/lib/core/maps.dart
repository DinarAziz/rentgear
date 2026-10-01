/// Tautan Google Maps untuk satu titik. Membuka aplikasi Maps bila terpasang,
/// atau maps.google.com di browser, tanpa API key.
Uri googleMapsUri(double latitude, double longitude) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': '$latitude,$longitude'},
);
