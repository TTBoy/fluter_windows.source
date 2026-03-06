
import 'package:qa_imageprocess/model/prompt/collector_type.dart';

class CategoryModel {
  String categoryName;
  String prompt;
  List<String> difficulties;
  List<CollectorType> collectorTypes;
  String example;

  CategoryModel({
    required this.categoryName,
    required this.prompt,
    required this.difficulties,
    required this.collectorTypes,
    required this.example,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      categoryName: json['categoryName'] as String,
      prompt: json['prompt'] as String,
      difficulties: (json['difficulties'] as List)
          .map((e) => e.toString())
          .toList(),
      collectorTypes: (json['collectorTypes'] as List)
          .map((e) => CollectorType.fromJson(e as Map<String, dynamic>))
          .toList(),
      example: json['example'] as String,
    );
  }
}