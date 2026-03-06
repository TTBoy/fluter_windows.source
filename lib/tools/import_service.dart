import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/widgets.dart';
import 'package:qa_imageprocess/user_session.dart';

class ImportService {
  final BuildContext context;

  // 回调函数定义
  final Function(int totalFound, int toUploadCount)? onStart;
  final Function(int current, int total, String fileName, bool success)?
  onProgress;
  final Function(int successCount, int skipCount, int errorCount)? onComplete;
  final Function(bool isResolving)? onResolve;

  ImportService({
    required this.context,
    this.onResolve,
    this.onStart,
    this.onProgress,
    this.onComplete,
  });

  // 主导入方法
  Future<void> importImages() async {
    int totalFound = 0;
    int skipCount = 0;
    int errorCount = 0;
    int successCount = 0;

    try {
      // 选择文件夹
      String? selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null) return;

      // 检查config.json
      File configFile = File(path.join(selectedPath, 'config.json'));
      if (!await configFile.exists()) {
        print("config.json not found");
        return;
      }
      if (onResolve != null) {
        onResolve!(true);
      }
      // 读取并解析JSON
      String jsonContent = await configFile.readAsString();
      List<dynamic> configList = json.decode(jsonContent);
      totalFound = configList.length;

      // 存储需要上传的图片信息
      List<Map<String, dynamic>> toUpload = [];

      // 检查图片是否存在
      for (var item in configList) {
        String imagePath = item['image_1'];
        String fileName = path.basename(imagePath);
        String category = item['text_image_domain'];

        // 检查本地图片文件是否存在
        File imageFile = File(path.join(selectedPath, imagePath));
        if (!await imageFile.exists()) {
          print("Image file not found: $imagePath");
          skipCount++;
          continue;
        }

        // 检查服务器是否已存在该图片
        bool exists = await _checkImageExists(fileName, category);
        if (exists) {
          print("Image already exists: $fileName");
          skipCount++;
          continue;
        }

        // 处理选项文本
        List<String> answers = _parseAnswers(item['text_opinion']);

        // 计算正确答案索引
        int? rightIndex = _getRightAnswerIndex(item['text_answer'], answers);

        // 转换难度
        int difficulty = _convertDifficulty(item['text_QA_diff']);

        // 添加到上传列表
        toUpload.add({
          'item': item,
          'filePath': imageFile.path,
          'fileName': fileName,
          'answers': answers,
          'rightIndex': rightIndex,
          'difficulty': difficulty,
        });
      }
      if (onResolve != null) {
        onResolve!(false);
      }

      // 触发开始回调
      if (onStart != null) {
        onStart!(totalFound, toUpload.length);
      }

      // 上传图片
      for (int i = 0; i < toUpload.length; i++) {
        var uploadItem = toUpload[i];
        try {
          bool success = await _uploadImage(uploadItem);
          if (success) {
            successCount++;
            if (onProgress != null) {
              onProgress!(i + 1, toUpload.length, uploadItem['fileName'], true);
            }
          } else {
            errorCount++;
            if (onProgress != null) {
              onProgress!(
                i + 1,
                toUpload.length,
                uploadItem['fileName'],
                false,
              );
            }
          }
        } catch (e) {
          errorCount++;
          print("Upload error: $e");
          if (onProgress != null) {
            onProgress!(i + 1, toUpload.length, uploadItem['fileName'], false);
          }
        }
      }

      print(
        "Import completed: $successCount images uploaded, $skipCount skipped, $errorCount errors",
      );
    } catch (e) {
      print("Import failed: $e");
      errorCount++;
    } finally {
      // 触发完成回调
      if (onComplete != null) {
        onComplete!(successCount, skipCount, errorCount);
      }
    }
  }

  // 检查图片是否存在
  Future<bool> _checkImageExists(String fileName, String category) async {
    final url = Uri.parse(
      '${UserSession().baseUrl}/api/image/check-exists',
    ).replace(queryParameters: {'fileName': fileName, 'category': category});

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${UserSession().token}'},
      );
      // print(response.body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print("Check exists error: $e");
      return false;
    }
  }

  // 解析选项文本
  List<String> _parseAnswers(String opinionText) {
    return opinionText.split(';').map((option) {
      // 移除选项前缀 (如 "A. ")
      return option.replaceAll(RegExp(r'^[A-Z]\.\s*'), '').trim();
    }).toList();
  }

  // 获取正确答案索引
  int? _getRightAnswerIndex(String answerText, List<String> answers) {
    if (answerText.isEmpty) return null;

    // 提取答案字母 (如 "A")
    RegExpMatch? match = RegExp(r'^([A-Z])\.').firstMatch(answerText);
    if (match == null) return null;

    String letter = match.group(1)!;
    return letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
  }

  // 转换难度等级
  int _convertDifficulty(String diffText) {
    switch (diffText) {
      case '简单':
        return 0;
      case '中等':
        return 1;
      case '困难':
        return 2;
      default:
        return 0;
    }
  }

  // 上传图片和关联数据 - 返回是否成功
  Future<bool> _uploadImage(Map<String, dynamic> uploadItem) async {
    final item = uploadItem['item'];
    final filePath = uploadItem['filePath'];
    final answers = uploadItem['answers'];
    final rightIndex = uploadItem['rightIndex'];
    final difficulty = uploadItem['difficulty'];

    final url = Uri.parse('${UserSession().baseUrl}/api/image/with-qa');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer ${UserSession().token}'
      ..fields['category'] = item['text_image_domain']
      ..fields['collector_type'] = item['text_image_type']
      ..fields['question_direction'] = item['text_QA_direction']
      ..fields['difficulty'] = difficulty.toString()
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    // 可选参数
    if (item['text_question'] != null) {
      request.fields['questionText'] = item['text_question'];
    }
    if (answers.isNotEmpty) {
      request.fields['answers'] = json.encode(answers);
    }
    if (rightIndex != null) {
      request.fields['rightAnswerIndex'] = rightIndex.toString();
    }
    if (item['text_COT'] != null) {
      request.fields['textCOT'] = item['text_COT'];
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print(responseBody);
      if (response.statusCode == 200) {
        print("Uploaded: ${uploadItem['fileName']}");
        return true;
      } else {
        print(
          "Upload failed (${response.statusCode}): ${uploadItem['fileName']}",
        );
        return false;
      }
    } catch (e) {
      print("Upload error: $e - ${uploadItem['fileName']}");
      return false;
    }
  }
}
