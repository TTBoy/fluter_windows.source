import 'package:qa_imageprocess/model/originator_model.dart';
import 'package:qa_imageprocess/model/question_model.dart';

//图片类
class ImageModel {
  final int imageID;
  final String? fileName;
  final String category;
  final String collectorType;
  final String questionDirection;
  final List<QuestionModel>? questions; // 存储多个问题
  final int? difficulty;
  final String? path;
  final int state;
  final String created_at;
  final String updated_at;
  final int originatorID;
  final Originator originator;
  final int? workID;

  ImageModel({
    required this.imageID,
    this.fileName,
    required this.category,
    required this.collectorType,
    required this.questionDirection,
    this.questions,
    this.difficulty,
    this.path,
    required this.state,
    required this.created_at,
    required this.updated_at,
    required this.originatorID,
    required this.originator,
    this.workID,
  });

  factory ImageModel.fromJson(Map<String, dynamic> json) {
  // 安全处理 questions 字段
  List<QuestionModel> questions = [];

  if (json['questions'] != null && json['questions'] is List) {
    questions = (json['questions'] as List)
        .map((questionJson) => QuestionModel.fromJson(questionJson))
        .toList();
  }

  return ImageModel(
    imageID: json['id'] as int? ?? 0,
    fileName: json['file_name'] as String?,
    category: json['category'] as String? ?? '',
    collectorType: json['collector_type'] as String? ?? '',
    questionDirection: json['question_direction'] as String? ?? '',
    questions: questions,
    difficulty: json['difficulty'] as int?,
    path: json['path'] as String?,
    state: json['state'] as int? ?? 0,
    created_at: json['created_at'] as String? ?? '',
    updated_at: json['updated_at'] as String? ?? '',
    originatorID: (json['originator'] as Map<String, dynamic>?)?['id'] as int? ?? 0,
    workID: json['workID'] as int?,
    originator: Originator.fromJson(
      json['originator'] as Map<String, dynamic>? ?? {},
    ),
  );
}

  ImageModel copyWith({
    int? imageID,
    String? fileName,
    String? category,
    String? collectorType,
    String? questionDirection,
    List<QuestionModel>? questions,
    int? difficulty,
    String? path,
    int? state,
    String? created_at,
    String? updated_at,
    int? originatorID,
    int? checkImageListID,
    int? workID,
    Originator? originator,
  }) {
    return ImageModel(
      imageID: imageID ?? this.imageID,
      fileName: fileName ?? this.fileName,
      category: category ?? this.category,
      collectorType: collectorType ?? this.collectorType,
      questionDirection: questionDirection ?? this.questionDirection,
      questions: questions ?? this.questions,
      difficulty: difficulty ?? this.difficulty,
      path: path ?? this.path,
      state: state ?? this.state,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
      originatorID: originatorID ?? this.originatorID,
      workID: workID ?? this.workID,
      originator: originator ?? this.originator,
    );
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> questionsJson = questions!
        .map((question) => question.toJson())
        .toList();

    return {
      'id': imageID,
      'file_name': fileName,
      'category': category,
      'collector_type': collectorType,
      'question_direction': questionDirection,
      'difficulty': difficulty,
      'path': path,
      'state': state,
      'created_at': created_at,
      'updated_at': updated_at,
      'originator_id': originatorID,
      'workID':workID,
      'originator': originator.toJson(),
      'questions': questionsJson, // 添加 questions 到 JSON 中
    };
  }

  @override
  String toString() {
    return 'ImageModel(imageID: $imageID, fileName: $fileName, category: $category, questions: $questions)';
  }
}
