class PlantSpeciesCandidate {
  const PlantSpeciesCandidate({
    required this.referenceId,
    required this.displayName,
    required this.scientificName,
    required this.categorySuggestion,
    this.familyName,
    this.floweringPeriod,
  });

  factory PlantSpeciesCandidate.fromJson(Map<String, dynamic> json) {
    final referenceId = json['reference_id'];
    final displayName = json['display_name'];
    if (referenceId is! String || displayName is! String) {
      throw const FormatException('Invalid species candidate');
    }
    return PlantSpeciesCandidate(
      referenceId: referenceId,
      displayName: displayName,
      scientificName: json['scientific_name'] as String? ?? '',
      categorySuggestion: json['category'] as String? ?? '',
      familyName: json['family_name'] as String?,
      floweringPeriod: json['flowering_period'] as String?,
    );
  }

  final String referenceId;
  final String displayName;
  final String scientificName;
  final String categorySuggestion;
  final String? familyName;
  final String? floweringPeriod;
}
