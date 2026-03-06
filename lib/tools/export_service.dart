import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:qa_imageprocess/model/answer_model.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/user_session.dart';
import 'package:image/image.dart' as img; // 添加image包用于获取图片尺寸


//导出交付文件
class ExportService {
  final BuildContext context;
  final String category;
  bool is_opinion = true;
  bool is_answer = true;
  bool is_COT = true;

  final String? startTime; // 开始时间戳
  final String? endTime; // 结束时间戳
  ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  ValueNotifier<String> status = ValueNotifier<String>('准备导出');
  final List<ImageModel>? images;

  final int concurrentDownloads; //并发下载数量控制

  ExportService({
    required this.context,
    required this.category,
    this.is_opinion = true,
    this.is_answer = true,
    this.is_COT = true,
    this.startTime,
    this.endTime,
    this.concurrentDownloads = 4,
    this.images,
  });

  // 获取所有图片（分页）
  Future<List<ImageModel>> _fetchAllImages() async {
    int currentPage = 1;
    int totalPages = 1;
    List<ImageModel> allImages = [];

    do {
      status.value = '正在获取图片 (第 $currentPage 页)...';

      final Map<String, String> queryParams = {
        'page': currentPage.toString(),
        'pageSize': 60.toString(),
      };

      queryParams['category'] = category;

      if (startTime != null) {
        queryParams['startTime'] = startTime!;
      }
      if (endTime != null) {
        queryParams['endTime'] = endTime!;
      }

      // 构建URL
      final uri = Uri.parse(
        '${UserSession().baseUrl}/api/image',
      ).replace(queryParameters: queryParams);

      try {
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
        );
        print(response.body);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final pagination = data['data'];
          final imageData = pagination['data'] as List;
          totalPages = pagination['totalPages'];

          allImages.addAll(
            imageData.map((img) => ImageModel.fromJson(img)).toList(),
          );
          progress.value = currentPage / totalPages * 0.2;
          currentPage++;
        } else {
          status.value = '网络错误: ${response.statusCode}';
          break;
        }
      } catch (e) {
        status.value = '获取图片失败: $e';
        break;
      }
    } while (currentPage <= totalPages);

    return allImages;
  }

  // 显示文件夹选择器
  Future<Directory?> _selectExportDirectory() async {
    try {
      final String? directoryPath = await getDirectoryPath();
      if (directoryPath != null) {
        return Directory(directoryPath);
      }
      return null;
    } catch (e) {
      status.value = '文件夹选择失败: $e';
      return null;
    }
  }

  // 导出主要方法
  Future<void> exportImages() async {
    try {
      progress.value = 0.0;

      // 1. 选择导出目录
      final directory = await _selectExportDirectory();
      if (directory == null) {
        status.value = '导出已取消';
        return;
      }
      List<ImageModel>? _images=this.images;
      // if(_images==null||_images.isEmpty){
      //   // _images=await _fetchAllImages();
      // }
      if (_images==null||_images.isEmpty) {
        status.value = '没有可导出的图片';
        return;
      }

      // 3. 创建日期文件夹
      final dateFolder = DateFormat('yyyyMMdd').format(DateTime.now());
      final dateDir = Directory(path.join(directory.path, dateFolder));
      if (!dateDir.existsSync()) dateDir.createSync(recursive: true);

      // 4. category分组
      final categoryGroups = groupBy(_images, (image) => image.category);

      // 5. 逐组导出
      int totalImages = _images.length;
      int processed = 0;

      for (final category in categoryGroups.keys) {
        // 跳过无效类别
        if (category == null || category.isEmpty) continue;

        status.value = '正在导出类别: $category';

        // 创建category文件夹
        final categoryDir = Directory(path.join(dateDir.path, category));
        if (!categoryDir.existsSync()) categoryDir.createSync(recursive: true);

        // 准备配置文件数据
        List<Map<String, dynamic>> configData = [];

        // 按collectorType分组
        final typeGroups = groupBy(
          categoryGroups[category]!,
          (image) => image.collectorType,
        );

        for (final collectorType in typeGroups.keys) {
          // 跳过无效收集器类型
          if (collectorType == null || collectorType.isEmpty) continue;

          // 创建collectorType文件夹
          final typeDir = Directory(path.join(categoryDir.path, collectorType));
          if (!typeDir.existsSync()) typeDir.createSync(recursive: true);

          final imagesInType = typeGroups[collectorType]!;

          // 创建下载队列
          final downloadQueue = Queue<ImageModel>.from(imagesInType);
          final List<Future<void>> activeDownloads = [];
          while (downloadQueue.isNotEmpty || activeDownloads.isNotEmpty) {
            // 启动新下载（不超过并发限制）
            // 修改这部分代码
            while (activeDownloads.length < concurrentDownloads &&
                downloadQueue.isNotEmpty) {
              final image = downloadQueue.removeFirst();

              // 使用临时变量存储 future
              final tempFuture = _processImage(
                image: image,
                saveDir: typeDir.path,
                configData: configData,
              );

              // 使用 tempFuture 而不是 future
              tempFuture.whenComplete(() {
                activeDownloads.remove(tempFuture);
                processed++;
                progress.value = 0.2 + (processed / totalImages * 0.8);
              });

              activeDownloads.add(tempFuture);
            }

            // 等待部分任务完成
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }

        try {
          status.value = '正在保存配置文件: $category/config.json';
          final configFile = File(path.join(categoryDir.path, 'config.json'));
          // 使用格式化编码器 (缩进为2个空格)
          final encoder = JsonEncoder.withIndent('  ');
          // await configFile.writeAsString(encoder.convert(configData));
          await configFile.writeAsString(
            encoder.convert(configData.isNotEmpty ? configData : []),
          );
        } catch (e) {
          status.value = '配置文件保存失败: $e';
        }
      }

      status.value = '导出完成！共导出 $processed 张图片';
      progress.value = 1.0;
    } catch (e) {
      status.value = '导出失败: $e';
      rethrow;
    }
  }

  /// 处理单个图片（下载+生成配置项）
  Future<void> _processImage({
    required ImageModel image,
    required String saveDir,
    required List<Map<String, dynamic>> configData,
  }) async {
    if (image.fileName == null || image.fileName!.isEmpty) return;

    status.value = '下载中: ${image.fileName} (${configData.length + 1})';

    try {
      final downloadResult = await _downloadImage(image, saveDir);
      if (downloadResult == null) return;

      final imageFile = downloadResult['file'];
      final imageSize = downloadResult['size'];

      // 生成配置文件数据
      final configItem = _createConfigItem(
        image: image,
        relativePath: path.join(
          image.collectorType,
          path.basename(imageFile.path),
        ),
        imageSize: imageSize,
      );

      configData.add(configItem);
    } catch (e) {
      status.value = '图片处理失败: $e';
    }
  }

  /// 创建配置项（抽离原有逻辑）
  Map<String, dynamic> _createConfigItem({
    required ImageModel image,
    required String relativePath,
    required String imageSize,
  }) {
    final question = image.questions?.isNotEmpty == true
        ? image.questions!.first
        : QuestionModel(
            questionID: -1,
            questionText: '',
            rightAnswer: AnswerModel(answerID: -1, answerText: ''),
            answers: [],
          );

    return _buildConfigItem(
      image,
      question,
      relativePath.replaceAll('\\', '/'),
      imageSize: imageSize,
    );
  }

  // 下载单个图片并获取尺寸信息
  Future<Map<String, dynamic>?> _downloadImage(
    ImageModel image,
    String savePath,
  ) async {
    if (image.imageID <= 0) return null;

    try {
      final uri = Uri.parse('${UserSession().baseUrl}/${image.path}');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        status.value = '下载失败: ${response.statusCode}';
        return null;
      }

      // 确定文件类型
      final fileName = image.fileName!;
      final contentType = response.headers['content-type'];
      String? fileExtension;

      if (contentType != null) {
        fileExtension = extensionFromMime(contentType);
      }

      // 如果无法从内容类型确定扩展名，尝试从文件名获取
      if (fileExtension == null && fileName.contains('.')) {
        fileExtension = path.extension(fileName);
      }

      // 默认使用.jpg
      fileExtension ??= '.jpg';

      // 创建有效的文件名
      String validFileName = fileName;
      if (!fileName.contains('.')) {
        validFileName = '$fileName$fileExtension';
      }

      // 保存文件
      final file = File(path.join(savePath, validFileName));
      await file.writeAsBytes(response.bodyBytes);

      // 获取图片尺寸信息
      String imageSize = '';
      try {
        final imageData = img.decodeImage(response.bodyBytes);
        if (imageData != null) {
          imageSize = '${imageData.width}x${imageData.height}';
        }
      } catch (e) {
        status.value = '获取图片尺寸失败: $e';
        // 即使获取尺寸失败，仍然继续导出图片
      }

      return {'file': file, 'size': imageSize};
    } catch (e) {
      status.value = '图片下载错误: $e';
      return null;
    }
  }

  // 构建配置文件条目
  Map<String, dynamic> _buildConfigItem(
    ImageModel image,
    QuestionModel question,
    String imagePath, {
    String imageSize = '', // 添加图片尺寸参数
  }) {
    // 将路径中的反斜杠替换为正斜杠
    imagePath = imagePath.replaceAll('\\', '/');

    // 生成选项文本 (A, B, C...)
    String optionsText = '';
    if (question.answers != null && question.answers!.isNotEmpty) {
      for (int i = 0; i < question.answers!.length; i++) {
        final letter = String.fromCharCode(65 + i); // A, B, C...
        final answerText = question.answers![i].answerText ?? '';
        optionsText += '$letter.$answerText\n';
      }
      optionsText = optionsText.trim();
    }

    // 安全获取各种可能为null的值
    final fileName = image.fileName ?? '';
    final textMd5 = fileName.isNotEmpty
        ? fileName.replaceAll(path.extension(fileName), '')
        : '';
    final category = image.category ?? '';
    final collectorType = image.collectorType ?? '';
    final questionDirection = image.questionDirection ?? '';
    final questionText = question.questionText ?? '';
    final rightAnswerText = question.rightAnswer?.answerText ?? '';
    final textCOT = question.textCOT ?? '';

    return {
      "image_1": imagePath, // 使用统一的正斜杠路径
      "text_md5": textMd5,
      "text_image_domain": category,
      "text_image_type": collectorType,
      "text_image_size": imageSize,
      "text_QA_diff": ImageState.getDifficulty(image.difficulty ?? -1) ?? '',
      "text_QA_direction": questionDirection,
      "text_question": questionText,
      "text_opinion": is_opinion ? optionsText : '',
      "text_answer": is_answer ? rightAnswerText : '',
      "text_COT": is_COT ? textCOT : '',
    };
  }

  // 辅助函数：按属性分组
  Map<K, List<T>> groupBy<T, K>(Iterable<T> values, K Function(T) keyFunction) {
    final map = <K, List<T>>{};
    for (final element in values) {
      final key = keyFunction(element);
      map.putIfAbsent(key, () => []).add(element);
    }
    return map;
  }
}

// 根据MIME类型获取文件扩展名
String? extensionFromMime(String mimeType) {
  const extensions = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'image/svg+xml': '.svg',
    'image/bmp': '.bmp',
    'image/tiff': '.tiff',
  };
  return extensions[mimeType];
}
