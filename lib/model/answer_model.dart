class AnswerModel {
  final int answerID;
  final String answerText;

  AnswerModel({required this.answerID, required this.answerText});

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      answerID: json['answerID'] as int? ?? 0,
      answerText: json['answerText'] as String? ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {'answerID': answerID, 'answerText': answerText};
  }

  // 在 AnswerModel 中添加
  AnswerModel copyWith({int? answerID, String? answerText}) {
    return AnswerModel(
      answerID: answerID ?? this.answerID,
      answerText: answerText ?? this.answerText,
    );
  }

  @override
  String toString() {
    return 'Originator(id: $answerID, name: $answerText)';
  }
}
