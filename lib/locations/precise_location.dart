class PreciseLocation {
  const PreciseLocation._(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  static PreciseLocation? fromValues(num? latitude, num? longitude) {
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return PreciseLocation._(
      double.parse(latitude.toStringAsFixed(6)),
      double.parse(longitude.toStringAsFixed(6)),
    );
  }

  static PreciseLocation? fromData(Object? value) {
    if (value is! Map) return null;
    final lat = value['latitude'];
    final lng = value['longitude'];
    return lat is num && lng is num ? fromValues(lat, lng) : null;
  }

  Map<String, double> get data => {
    'latitude': latitude,
    'longitude': longitude,
  };

  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}
