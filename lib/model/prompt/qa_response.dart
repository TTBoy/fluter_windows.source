import 'dart:convert';

class QaResponse {
  String question; //问题
  List<String> options; //选项
  int correctAnswer; //正确选项索引
  String explanation; //答案解析
  String textCOT; //解题思维链
  QaResponse({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.textCOT,
  });

  factory QaResponse.fromJson(Map<String, dynamic> json) {
    return QaResponse(
      question: json['question'] as String,
      options: (json['options'] as List).map((e) => e.toString()).toList(),
      correctAnswer: json['correct_answer'] as int,
      explanation: json['explanation'] as String,
      textCOT: json['text_COT'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'text_COT': textCOT,
    };
  }

  static QaResponse parseContent(String content) {
    try {
      // 处理无标记的纯JSON
      if (content.trim().startsWith('{')) {
        return QaResponse.fromJson(
          json.decode(content) as Map<String, dynamic>,
        );
      }

      // 处理带```json标记的
      final regex = RegExp(r'```(?:json)?\n([\s\S]+?)\n```');
      final match = regex.firstMatch(content);

      if (match == null) {
        throw FormatException('无法识别的内容格式');
      }

      final jsonData = json.decode(match.group(1)!) as Map<String, dynamic>;
      return QaResponse.fromJson(jsonData);
    } on FormatException {
      // 尝试修复常见格式问题
      final sanitized = content
          .replaceAll(RegExp(r'[\r\n\t]'), ' ')
          .replaceAll(RegExp(r'\\+'), '\\');

      try {
        return QaResponse.fromJson(
          json.decode(sanitized) as Map<String, dynamic>,
        );
      } catch (_) {
        rethrow;
      }
    }
  }
  @override
  String toString() {
    // TODO: implement toString
    return 'question:$question  answers:${options.toString()} rightAswer:${options[correctAnswer]}';
  }
}
