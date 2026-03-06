import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:qa_imageprocess/model/CompressionParams.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/prompt/category_model.dart';
import 'package:qa_imageprocess/model/prompt/qa_answer.dart';
import 'package:qa_imageprocess/model/prompt/qa_explanation.dart';
import 'package:qa_imageprocess/model/prompt/qa_response.dart';
import 'package:qa_imageprocess/user_session.dart';

class AiService {
  static final Duration _TimeOut = Duration(seconds: 50);

  static List<CategoryModel> categorys = [];
  static String rule = '';
  static String formatRule = '';

  static Future<void> initData() async {
    try {
      // 1. 加载JSON文件
      final jsonString = await rootBundle.loadString('assets/prompt.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // 2. 解析规则字符串
      rule = jsonData['rule']?.toString() ?? '';

      // 3. 解析formatRule为JSON字符串
      final formatRuleObj = jsonData['formatRule'];
      if (formatRuleObj != null) {
        formatRule = jsonEncode(formatRuleObj);
      }

      // 4. 解析分类数据
      final data = jsonData['data'] as Map<String, dynamic>?;
      final categoriesJson = data?['categorys'] as List<dynamic>?;

      if (categoriesJson != null) {
        categorys = categoriesJson.map((e) {
          return CategoryModel.fromJson(e as Map<String, dynamic>);
        }).toList();
      }
    } catch (e) {
      // 错误处理
      print('Error loading prompt data: $e');
      // 可以根据需要设置默认值
      rule = 'Failed to load rules';
      formatRule = 'Failed to load format rules';
    }
  }

  static Future<QaResponse?> getQA(
    ImageModel image, {
    int questionDifficulty = 0,
  }) async {
    try {
      // 1. 发送请求
      final response = await http.post(
        Uri.parse(UserSession().apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession().apiKey}',
        },
        body: await _getRequestBody(image),
      );
      print(response.body);
      // 2. 检查HTTP状态码
      if (response.statusCode != 200) {
        throw HttpException('请求失败，状态码: ${response.statusCode}');
      }

      // 3. 解析响应体
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      // print(responseBody);

      // 4. 提取content内容
      final content = _extractContent(responseBody);
      if (content == null) {
        throw FormatException('响应中缺少有效content');
      }

      // 5. 解析为QaResponse对象
      return QaResponse.parseContent(content);
    } on http.ClientException catch (e) {
      print('网络请求异常: $e');
      return null;
    } on FormatException catch (e) {
      print('JSON解析失败: $e');
      return null;
    } catch (e) {
      print('未知错误: $e');
      return null;
    }
  }

  static Future<QaAnswer?> getAnswer(ImageModel image) async {
    try {
      final response = await http.post(
        Uri.parse((UserSession().apiUrl)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession().apiKey}',
        },
        body: await _getAnswerBody(image),
      );
      print(response.body);
      if (response.statusCode != 200) {
        throw HttpException('请求失败，状态码：${response.statusCode}');
      }
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      final content = _extractContent(responseBody);
      print(content);
      if (content == null) {
        throw FormatException('响应中缺少content');
      }
      return QaAnswer.extractQaAnswerFromAiResponse(content!);
    } catch (e) {
      print('API错误');
      return null;
    }
  }

  //根据问题答案获取解析和COT
  static Future<QaExplanation?> getExplanationAndCOT(ImageModel image) async {
    try {
      final response = await http.post(
        Uri.parse((UserSession().apiUrl)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession().apiKey}',
        },
        body: await _getExplanationAndCOTBody(image),
      );
      print(response.body);
      if (response.statusCode != 200) {
        throw HttpException('请求失败，状态码：${response.statusCode}');
      }
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      final content = _extractContent(responseBody);
      if (content == null) {
        throw FormatException('响应中缺少content');
      }
      return QaExplanation.extractQaExplanationFromAiResponse(content!);
    } catch (e) {
      print('API错误');
      return null;
    }
  }

  //根据问题和答案获取解题过程和COT的请求体以及提示词
  static Future<String> _getExplanationAndCOTBody(ImageModel image) async {
    String imageBase64 = await downloadAndProcessImage(
      '${UserSession().baseUrl}/${image.path}',
    );
    String prompt =
        '''根据图片和问题以及答案，编写解析，和解题思路。问题：${image.questions!.first.questionText}；选项：${image.questions!.first.answers};答案：${image.questions!.first.rightAnswer.answerText};
    你需要按照json格式输出。
    输出示例：
    {
    "explanation":"正确答案的解释",
    "COT":"第一步、第二步、第三步……"
    }
    其中explanation是正确答案的解释，COT是解题步骤，要按照第一步、第二步、第三步……的格式。答案的解释和解题步骤要简单明了，字数不要太多。''';
    final requestBody = {
      'model': UserSession().modelName,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
      'max_tokens': 8000,
      'temperature': 0.7,
    };
    // print(requestBody);
    return jsonEncode(requestBody);
  }

  //根据问题获取答案的请求体和提示词
  static Future<String> _getAnswerBody(ImageModel image) async {
    String imageBase64 = await downloadAndProcessImage(
      '${UserSession().baseUrl}/${image.path}',
    );
    String prompt =
        '''根据图片和问题生成答案选项，以及解析，还要包含解题思路。问题：${image.questions!.first.questionText};
    你需要按照json格式输出。
    输出示例：
    {
    "answers": [
        "answer1",
        "answer2",
        "answer3",
        "answer4"
    ],
    "rightAnswerIndex":0,
    "explanation":"正确答案的解释",
    "COT":"第一步、第二步、第三步……"
    }
    选项不要带有字母。
    其中answers数组包含每一个答案选项，rightAnswerIndex表示正确答案的索引，explanation是正确答案的解释，COT是解题步骤，要按照第一步、第二步、第三步……的格式。答案的解释和解题步骤要简单明了，字数不要太多。''';
    final requestBody = {
      'model': UserSession().modelName,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
      'max_tokens': 8000,
      'temperature': 0.7,
    };
    print(prompt);

    return jsonEncode(requestBody);
  }

  // 辅助方法：从响应体中提取content
  static String? _extractContent(Map<String, dynamic> responseBody) {
    try {
      final choices = responseBody['choices'] as List;
      if (choices.isEmpty) return null;

      final firstChoice = choices.first as Map<String, dynamic>;
      return firstChoice['message']['content'] as String;
    } catch (e) {
      return null;
    }
  }

  static String getPrompt(
    List<CategoryModel> categorys,
    ImageModel image, {
    int questionDifficulty = 0,
  }) {
    // print(image.category);
    CategoryModel? category = categorys.firstWhere(
      (item) => item.categoryName == image.category,
    );
    print(category.categoryName);
    return '''请仔细观察这张图片，基于图片内容生成一个${category.categoryName}类问题，问题难度为${image.difficulty}(${ImageState.getDifficulty(image.difficulty ?? 0)}。
    问题需要${category.prompt}
    问题要具备：
    ${category.difficulties[image.difficulty ?? 0]};
    当前图片提问方向：${image.collectorType}的${image.questionDirection};
    ${getPromptRule(image, questionDifficulty: questionDifficulty)};
    【输出格式要求】：
    $formatRule；
    选项不要带字母。
    (correct_answer是正确答案位置索引，解题步骤要精简，逻辑清晰);
    ''';
  }
  //    问题参考样例：
  //${category.example};

  static String getPromptRule(ImageModel image, {int questionDifficulty = 0}) {
    switch (image.category) {
      case 'single_instance_reasoning（单实例推理）':
        switch (questionDifficulty) {
          case 0:
            return '''
            画面主体是${image.category},你要对画面主体的${image.questionDirection}结合相关的外部知识进行提问，满足基础的推理性问题;
          ''';
          case 1:
            return '''
            画面主体是${image.category},你要对画面主体的${image.questionDirection}结合相关进行提问，满足较复杂的推理性问题;
          ''';
          default:
            return '';
        }

      case 'common reasoning（常识推理）' ||
          'statistical reasoning（统计推理）' ||
          'diagram reasoning（图表推理）':
        switch (questionDifficulty) {
          case 0:
            return '''
            需要结合外部知识进行推理；
            对画面的${image.questionDirection}结合相关${image.collectorType}外部知识进行提问，满足单步的推理。
            ''';
          case 1:
            return '''
            需要结合外部知识进行推理；
            对画面的${image.questionDirection}结合相关${image.collectorType}外部知识进行提问，满足多部的推理。
            ''';
          default:
            return '';
        }
      case 'geography_earth_agri（地理&地球科学&农业）':
        switch (questionDifficulty) {
          case 0:
            return '''
            对画面的${image.questionDirection}结合相关初中知识知识进行提问。
            ''';
          case 1:
            return '''
            对画面的${image.questionDirection}结合高中知识进行提问。
            ''';
          default:
            return '';
        }
      default:
        return '';
    }
  }

  static Future<String> _getRequestBody(
    ImageModel image, {
    int questionDifficulty = 0,
  }) async {
    String imageBase64 = await downloadAndProcessImage(
      '${UserSession().baseUrl}/${image.path}',
    );
    String prompt = getPrompt(
      categorys,
      image,
      questionDifficulty: questionDifficulty,
    );
    print('提示词：$prompt');
    final requestBody = {
      'model': UserSession().modelName,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
      'max_tokens': 8000,
      'temperature': 0.7,
    };

    return jsonEncode(requestBody);
  }

  // 下载图片并转换为base64
  static Future<String> downloadAndProcessImage(String imgUrl) async {
    try {
      final response = await http.get(Uri.parse(imgUrl));
      if (response.statusCode == 200) {
        final originalBytes = response.bodyBytes;

        // 分析原始图片大小
        final originalSizeKb = originalBytes.length / 1024;
        print('原始图片大小: ${originalSizeKb.toStringAsFixed(2)} KB');

        // 解码图片
        final img.Image? image = img.decodeImage(originalBytes);
        if (image == null) throw Exception('图片解码失败');

        // 根据原始大小动态设置压缩参数
        final compressionParams = _calculateCompressionParams(originalSizeKb);

        // 调整大小
        final resized = img.copyResize(
          image,
          width: compressionParams.targetWidth,
          height: compressionParams.targetHeight,
        );

        // 转换为JPEG并设置动态质量
        final compressedBytes = img.encodeJpg(
          resized,
          quality: compressionParams.quality,
        );

        final compressedSizeKb = compressedBytes.length / 1024;
        print(
          '压缩后大小: ${compressedSizeKb.toStringAsFixed(2)} KB (质量: ${compressionParams.quality}%)',
        );

        return base64Encode(compressedBytes);
      } else {
        throw Exception('图片下载失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('图片处理错误: $e');
    }
  }

  static CompressionParams _calculateCompressionParams(double originalSizeKb) {
    // 默认参数（小图片）
    int width = 800;
    int height = 800;
    int quality = 85;

    if (originalSizeKb > 1024) {
      // 大于1MB
      width = 600;
      quality = 70;
    } else if (originalSizeKb > 512) {
      // 512KB-1MB
      width = 700;
      quality = 75;
    } else if (originalSizeKb > 256) {
      // 256KB-512KB
      width = 800;
      quality = 80;
    } else if (originalSizeKb > 128) {
      // 128KB-256KB
      width = 1000;
      quality = 85;
    }
    // 小于128KB保持原质量

    // 确保不超过常见最大尺寸
    width = width.clamp(400, 1200);
    height = height.clamp(400, 1200);
    quality = quality.clamp(60, 95);

    return CompressionParams(
      targetWidth: width,
      targetHeight: height,
      quality: quality,
    );
  }
}
