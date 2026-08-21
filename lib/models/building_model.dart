class BuildingLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double allowedRadiusMeters;

  BuildingLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.allowedRadiusMeters = 200.0,
  });

  factory BuildingLocation.fromMap(String id, Map<String, dynamic> data) {
    return BuildingLocation(
      id: id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      allowedRadiusMeters: (data['allowedRadiusMeters'] as num?)?.toDouble() ?? 200.0,
    );
  }
}