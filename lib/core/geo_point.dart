class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}
