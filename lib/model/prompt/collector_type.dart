class CollectorType {
  final String collectorTypeName;
  final List<String> questionDirections;

  CollectorType({
    required this.collectorTypeName,
    required this.questionDirections,
  });

  factory CollectorType.fromJson(Map<String, dynamic> json) {
    return CollectorType(
      collectorTypeName: json['collectorTypeName'] as String,
      questionDirections: (json['questionDirections'] as List)
          .map((e) => e.toString())
          .toList(),
    );
  }
}