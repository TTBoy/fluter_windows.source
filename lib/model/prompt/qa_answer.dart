import 'dart:convert';

class QaAnswer {
  List<String> answers;
  int rightAnswerIndex;
  String explanation;
  String COT;

  QaAnswer({
    required this.answers,
    required this.rightAnswerIndex,
    required this.explanation,
    required this.COT,
  });

  factory QaAnswer.fromJson(Map<String, dynamic> json) {
    return QaAnswer(
      answers: List<String>.from(json['answers']),
      rightAnswerIndex: json['rightAnswerIndex'] as int,
      explanation: json['explanation'] as String,
      COT: json['COT'] as String,
    );
  }

  /// 从AI回复文本中提取JSON内容
  static QaAnswer extractQaAnswerFromAiResponse(String aiResponse) {
  try {
    // 尝试直接解析整个响应
    final trimmedResponse = aiResponse.trim();
    if (trimmedResponse.startsWith('{') && trimmedResponse.endsWith('}')) {
      return QaAnswer.fromJson(jsonDecode(trimmedResponse) as Map<String, dynamic>);
    }

    // 尝试提取json代码块
    final regex = RegExp(r'```(?:json)?\n([\s\S]+?)\n```');
    final match = regex.firstMatch(trimmedResponse);
    if (match != null) {
      final jsonString = match.group(1)!.trim();
      return QaAnswer.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    }

    // 尝试提取可能没有代码块标记的json内容
    final jsonRegex = RegExp(r'\{[\s\S]+\}');
    final jsonMatch = jsonRegex.firstMatch(trimmedResponse);
    if (jsonMatch != null) {
      return QaAnswer.fromJson(jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>);
    }

    throw FormatException('无法识别的内容格式');
  } catch (e) {
    print('JSON提取或解析错误: $e');
    throw FormatException('无法识别的内容格式: ${e.toString()}');
  }
}
}
