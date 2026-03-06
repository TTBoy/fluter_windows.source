import 'dart:convert';

class QaExplanation {
  String explanation;
  String COT;

  QaExplanation({required this.explanation, required this.COT});

  // fromJson 工厂方法
  factory QaExplanation.fromJson(Map<String, dynamic> json) {
    return QaExplanation(
      explanation: json['explanation'] as String,
      COT: json['COT'] as String,
    );
  }

  /// 从AI回复文本中提取QaExplanation JSON内容
  static QaExplanation extractQaExplanationFromAiResponse(String aiResponse) {
    try {
      // 使用正则表达式匹配JSON，支持被```包裹的情况
      final jsonPattern = RegExp(
        r'```(json)?\s*(\{[\s\S]*?\})\s*```|(\{[\s\S]*?\})',
      );
      final match = jsonPattern.firstMatch(aiResponse);

      if (match == null) return throw FormatException('无法识别的内容格式');

      // 获取匹配的JSON字符串
      final jsonString = match.group(2) ?? match.group(3);
      if (jsonString == null) return throw FormatException('无法识别的内容格式');

      // 解析JSON
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return QaExplanation.fromJson(jsonMap);
    } catch (e) {
      print('JSON提取或解析错误: $e');
      return throw FormatException('无法识别的内容格式');
    }
  }
}
