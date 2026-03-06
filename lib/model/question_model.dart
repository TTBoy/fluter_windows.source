import 'package:qa_imageprocess/model/answer_model.dart';

class QuestionModel {
  final int questionID;
  final String questionText;
  final AnswerModel rightAnswer; // 修改为AnswerModel类型
  final List<AnswerModel> answers;
  final String? explanation;
  final String? textCOT;

  QuestionModel({
    required this.questionID,
    required this.questionText,
    required this.rightAnswer, // 使用rightAnswer而非rightAnswerID
    required this.answers,
    this.explanation,
    this.textCOT,
  });

  // 修改工厂构造函数，解析rightAnswer为AnswerModel
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
  return QuestionModel(
    questionID: json['questionID'] as int? ?? 0,
    questionText: json['questionText'] as String? ?? '',
    rightAnswer: AnswerModel.fromJson(
      json['rightAnswer'] as Map<String, dynamic>? ?? {},
    ),
    answers: (json['answers'] as List<dynamic>?)
        ?.map((answerJson) => AnswerModel.fromJson(answerJson as Map<String, dynamic>? ?? {}))
        .toList() ?? [],
    explanation: json['explanation'],
    textCOT: json['textCOT']
  );
}

  // 修改toJson方法，返回rightAnswer的toJson
  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> answersJson = answers
        .map((answer) => answer.toJson())
        .toList();

    return {
      'questionID': questionID,
      'questionText': questionText,
      'rightAnswer': rightAnswer.toJson(), // 返回rightAnswer的toJson
      'answers': answersJson,
      'explanation':explanation??'',
      'textCOT':textCOT??'',
    };
  }

  QuestionModel copyWith({
  int? questionID,
  String? questionText,
  AnswerModel? rightAnswer,
  List<AnswerModel>? answers,
}) {
  return QuestionModel(
    questionID: questionID ?? this.questionID,
    questionText: questionText ?? this.questionText,
    rightAnswer: rightAnswer ?? this.rightAnswer,
    answers: answers ?? this.answers,
  );
}

  @override
  String toString() {
    return 'QuestionModel(id: $questionID, text: $questionText, rightAnswer: $rightAnswer, answers: ${answers.map((a) => a.toString()).join(", ")})';
  }
}
