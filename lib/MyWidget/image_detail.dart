import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/tools/DownloadHelper.dart';
// import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/user_session.dart';

typedef ImageUpdateCallback = void Function(ImageModel updatedImage);
typedef ImageDeleteCallback = void Function(int imageID);
typedef ImageAiQaCallback = void Function(ImageModel updatedImage);
typedef DeprecateImageCallBack = void Function(int imageID);
typedef ImageAnswerUpdatedCallback = void Function(ImageModel updatedImage);
typedef ImageExplanationUpdatedCallback =
    void Function(ImageModel updatedImage);

class ImageDetail extends StatefulWidget {
  final ImageModel image;
  final VoidCallback? onClose;
  final ImageUpdateCallback onImageUpdated;
  final ImageDeleteCallback? onImageDeleted;
  final ImageAiQaCallback? onImageOaUpdated;
  final DeprecateImageCallBack? onDeprecateImage;
  final ImageAnswerUpdatedCallback? onAnswerUpdated;
  final ImageExplanationUpdatedCallback? onExplanationUpdated;

  const ImageDetail({
    super.key,
    required this.image,
    this.onClose,
    required this.onImageUpdated,
    this.onImageDeleted,
    this.onImageOaUpdated,
    this.onDeprecateImage,
    this.onAnswerUpdated,
    this.onExplanationUpdated,
  });

  @override
  State<ImageDetail> createState() => _ImageDetailState();
}

class _ImageDetailState extends State<ImageDetail> {
  late ImageModel currentImage;
  bool _isProcessing = false;
  bool _isEditing = false; // 新增：编辑状态标志
  late List<TextEditingController> _answerControllers; // 答案文本控制器
  late TextEditingController _questionController; // 题目文本控制器
  late int _selectedCorrectIndex; // 选择的正确答案索引
  late TextEditingController _explanationController;
  late TextEditingController _textCOTController;

  // 添加分辨率变量
  int? _imageWidth;
  int? _imageHeight;

  // bool _isMagnifying = false;

  @override
  void initState() {
    super.initState();
    currentImage = widget.image;
    _initEditControllers(); // 初始化控制器
    // 计算图片分辨率
    _calculateImageResolution();
  }

  // 计算图片分辨率的方法
  void _calculateImageResolution() {
    final fullImagePath = '${UserSession().baseUrl}/${currentImage.path}';

    // 使用Image.network获取图片尺寸
    Image.network(fullImagePath).image
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            if (mounted) {
              setState(() {
                _imageWidth = info.image.width;
                _imageHeight = info.image.height;
              });
            }
          }),
        );
  }

  // 初始化（刷新）编辑控制器
  void _initEditControllers() {
    // 检查当前图片是否有问题数据
    final question =
        currentImage.questions != null && currentImage.questions!.isNotEmpty
        ? currentImage.questions!.first
        : null;

    // 初始化题目控制器
    _questionController = TextEditingController(
      text: question?.questionText ?? '',
    );

    _explanationController = TextEditingController(
      text: question?.explanation ?? '',
    );

    _textCOTController = TextEditingController(text: question?.textCOT ?? '');

    // 初始化答案控制器
    _answerControllers = [];
    if (question != null && question.answers.isNotEmpty) {
      for (var answer in question.answers) {
        _answerControllers.add(TextEditingController(text: answer.answerText));
      }
      // 设置当前正确答案索引
      final correctAnswerId = question.rightAnswer.answerID;
      _selectedCorrectIndex = question.answers.indexWhere(
        (a) => a.answerID == correctAnswerId,
      );
      if (_selectedCorrectIndex == -1) _selectedCorrectIndex = 0;
    } else {
      // 默认添加两个空答案
      _answerControllers = [TextEditingController(), TextEditingController()];
      _selectedCorrectIndex = 0;
    }
  }

  // 开始编辑
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  // 取消编辑
  void _cancelEditing() {
    // 重置为原始状态
    _initEditControllers();
    setState(() {
      _isEditing = false;
    });
  }

  // 添加答案选项
  void _addAnswer() {
    setState(() {
      _answerControllers.add(TextEditingController());
    });
  }

  // 移除答案选项
  void _removeAnswer(int index) {
    if (_answerControllers.length > 1) {
      setState(() {
        // 处理被删除的是正确答案的情况
        if (index == _selectedCorrectIndex) {
          _selectedCorrectIndex = 0;
        }
        // 处理删除后索引改变的情况
        else if (index < _selectedCorrectIndex) {
          _selectedCorrectIndex--;
        }

        final controller = _answerControllers.removeAt(index);
        controller.dispose();
      });
    }
  }

  // 提交编辑
  Future<void> _submitEdit() async {
    // 收集数据
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入问题内容')));
      return;
    }

    final answers = <String>[];
    for (var controller in _answerControllers) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        answers.add(text);
      }
    }

    if (answers.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少需要两个有效答案')));
      return;
    }

    if (_selectedCorrectIndex >= answers.length) {
      _selectedCorrectIndex = 0;
    }

    // 显示处理中
    setState(() => _isProcessing = true);

    try {
      // 调用API更新
      final updatedImage = await _updateImageQA(
        imageId: currentImage.imageID,
        questionText: questionText,
        answers: answers,
        rightAnswerIndex: _selectedCorrectIndex,
        explanation: _explanationController.text,
        textCOT: _textCOTController.text,
      );

      if (updatedImage != null) {
        // 更新状态
        setState(() {
          currentImage = updatedImage;
          _isEditing = false;
        });

        // 通知父组件
        widget.onImageUpdated(updatedImage);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('题目更新成功')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // 构建编辑界面
  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 题目编辑区域
        TextField(
          controller: _questionController,
          decoration: InputDecoration(
            labelText: '题目内容',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _questionController.clear(),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        // 答案编辑区域
        const Text(
          '答案选项:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // 答案列表
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _answerControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // 单选按钮
                  Radio<int>(
                    value: index,
                    groupValue: _selectedCorrectIndex,
                    onChanged: (value) =>
                        setState(() => _selectedCorrectIndex = value!),
                  ),

                  // 答案输入框
                  Expanded(
                    child: TextField(
                      controller: _answerControllers[index],
                      decoration: InputDecoration(
                        hintText: '答案选项 ${String.fromCharCode(65 + index)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),

                  // 删除按钮
                  if (_answerControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeAnswer(index),
                    ),
                ],
              ),
            );
          },
        ),

        // 添加答案按钮
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('添加答案'),
          onPressed: _addAnswer,
        ),
        const SizedBox(height: 20),

        //explanation编辑区
        TextField(
          controller: _explanationController,
          decoration: InputDecoration(
            labelText: '解析',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _explanationController.clear(),
            ),
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 10),
        //textCOT编辑区
        TextField(
          controller: _textCOTController,
          decoration: InputDecoration(
            labelText: '解题思维链',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _textCOTController.clear(),
            ),
          ),
          maxLines: 5,
        ),

        SizedBox(height: 10),

        // 操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: _cancelEditing, child: const Text('取消')),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isProcessing ? null : _submitEdit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('提交更新'),
            ),
          ],
        ),
      ],
    );
  }

  // 构建问题和答案展示组件
  Widget _buildQuestionAnswer(QuestionModel question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.questionText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(width: 15),

        const SizedBox(height: 8),
        _buildAnswerIndicators(question),
        const SizedBox(height: 16),
      ],
    );
  }

  // 正确答案指示器
  Widget _buildAnswerIndicators(QuestionModel question) {
    if (question.answers.isEmpty) return const SizedBox();

    // 找到正确答案
    final rightAnswerId = question.rightAnswer.answerID;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 答案指示器
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: question.answers.asMap().entries.map((entry) {
            final index = entry.key;
            final answer = entry.value;
            final isCorrect = answer.answerID == rightAnswerId;
            final letter = String.fromCharCode(65 + index); // A, B, C...

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$letter.',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    answer.answerText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCorrect ? Colors.green : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        if (widget.onExplanationUpdated != null)
          IconButton(
            onPressed: () => {widget.onExplanationUpdated!(currentImage)},
            icon: Icon(Icons.tips_and_updates),
            tooltip: '生成解析',
          ),
        const SizedBox(height: 16),

        // 解析部分
        if (question.explanation?.isNotEmpty ?? false) ...[
          const Text(
            '解析:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question.explanation!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 思维链部分
        if (question.textCOT?.isNotEmpty ?? false) ...[
          const Text(
            '解题思维链：',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question.textCOT!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  // 构建图片信息卡片（添加了InteractiveViewer缩放功能）
  Widget _buildImageCard() {
    final fullImagePath = '${UserSession().baseUrl}/${currentImage.path}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: InteractiveViewer(
          panEnabled: true, // 启用平移
          scaleEnabled: true, // 启用缩放
          minScale: 0.1, // 最小缩放级别
          maxScale: 5.0, // 最大缩放级别
          child: Image.network(
            fullImagePath,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '加载失败: ${error.toString()}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 构建信息展示项
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
    );
  }

  // 图片上传方法
  Future<void> _uploadImage() async {
    try {
      // 打开文件选择器，允许选择图片文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false, // 只允许选择单个文件
      );

      if (result != null && result.files.single.path != null) {
        // 获取选中的文件
        File file = File(result.files.single.path!);

        // 创建多部分请求
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${UserSession().baseUrl}/api/image/upload'),
        );

        // 添加授权头
        request.headers['Authorization'] =
            'Bearer ${UserSession().token ?? ''}';

        // 添加文件部分
        request.files.add(
          await http.MultipartFile.fromPath(
            'file', // 参数名，根据API文档
            file.path,
          ),
        );

        // 添加其他表单字段
        request.fields['image_id'] = currentImage.imageID
            .toString(); // 根据API文档，这个值可能需要动态获取

        // 发送请求
        var response = await request.send();
        var responseData = await response.stream.bytesToString();
        print(responseData);
        // 处理响应
        if (response.statusCode == 200) {
          // 读取响应内容
          // var responseData = await response.stream.bytesToString();
          var jsonResponse = json.decode(responseData);

          ImageModel newImage = ImageModel.fromJson(jsonResponse['data']);
          ImageModel updatedImage = currentImage.copyWith(
            fileName: newImage.fileName,
            path: newImage.path,
          );

          // 3. 更新UI状态
          if (mounted) {
            setState(() {
              currentImage = updatedImage;
              _initEditControllers();
              _isEditing = false;
            });
            widget.onImageUpdated(updatedImage);
          }

          if (jsonResponse['code'] == 200) {
            // 上传成功
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('图片上传成功')));

            // 可选：刷新图片列表
            // _fetchWorkDetails();
          } else {
            // 服务器返回错误
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('上传失败: ${jsonResponse['message']}')),
            );
          }
        } else {
          // HTTP错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  // 图片放大方法
  Future<void> _magnifyImage() async {
    // 检查当前图片是否已经满足分辨率要求
    if (_imageWidth != null && _imageHeight != null) {
      if (_imageWidth! >= 720 && _imageHeight! >= 720) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分辨率符合，无需放大')));
        return;
      }
    }

    try {
      // 1. 获取当前图片URL
      String imageUrl = '${UserSession().baseUrl}/${currentImage.path}';

      // 2. 下载原始图片
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('下载图片失败: HTTP ${response.statusCode}');
      }

      // 3. 解码图片
      Uint8List imageBytes = response.bodyBytes;
      img.Image originalImage = img.decodeImage(imageBytes)!;

      // 4. 计算放大比例（目标至少720像素）
      double scaleFactor = 1.0;

      // 如果任意一边小于720，则计算放大比例
      if (originalImage.width < 720 || originalImage.height < 720) {
        // 计算需要放大的比例
        double widthScale = originalImage.width < 720
            ? 720 / originalImage.width
            : 1.0;
        double heightScale = originalImage.height < 720
            ? 720 / originalImage.height
            : 1.0;

        // 取较大的比例，确保两边都至少达到720像素
        scaleFactor = widthScale > heightScale ? widthScale : heightScale;
      } else {
        // 如果两边都已经大于720，但之前检查未通过（可能是_imageWidth/_imageHeight未正确更新）
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分辨率符合，无需放大')));
        return;
      }

      // 5. 按比例放大图片
      img.Image magnifiedImage = img.copyResize(
        originalImage,
        width: (originalImage.width * scaleFactor).round(),
        height: (originalImage.height * scaleFactor).round(),
        interpolation: img.Interpolation.cubic, // 使用高质量插值算法
      );

      // 6. 保存放大后的图片到临时文件
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/magnified_${currentImage.imageID}.jpg';
      File magnifiedFile = File(filePath);
      await magnifiedFile.writeAsBytes(
        img.encodeJpg(magnifiedImage, quality: 95),
      );

      // 7. 上传放大后的图片
      await _uploadMagnifiedImage(magnifiedFile);

      // 8. 删除临时文件
      await magnifiedFile.delete();

      // 9. 显示成功消息
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片已成功放大并上传')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片放大失败: $e')));
    }
  }

  // 上传放大后的图片
  Future<void> _uploadMagnifiedImage(File magnifiedFile) async {
    try {
      // 创建多部分请求
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UserSession().baseUrl}/api/image/upload'),
      );

      // 添加授权头
      request.headers['Authorization'] = 'Bearer ${UserSession().token ?? ''}';

      // 添加文件部分
      request.files.add(
        await http.MultipartFile.fromPath('file', magnifiedFile.path),
      );

      // 添加其他表单字段
      request.fields['image_id'] = currentImage.imageID.toString();

      // 发送请求
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      print(responseData);

      // 处理响应
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseData);

        ImageModel newImage = ImageModel.fromJson(jsonResponse['data']);
        ImageModel updatedImage = currentImage.copyWith(
          fileName: newImage.fileName,
          path: newImage.path,
        );

        // 更新UI状态
        if (mounted) {
          setState(() {
            currentImage = updatedImage;
            _initEditControllers();
            _isEditing = false;
          });
          _calculateImageResolution();
          widget.onImageUpdated(updatedImage);
        }

        if (jsonResponse['code'] == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('放大图片上传成功')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: ${jsonResponse['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  //删除图片
  Future<void> _deleteImage(int imageID) async {
    try {
      final response = await http.delete(
        Uri.parse('${UserSession().baseUrl}/api/image/$imageID'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        if (mounted) {
          widget.onImageDeleted!(imageID);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除成功')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败')));
    }
  }

  //删除图片
  Future<void> _deprecateImage(int imageID) async {
    try {
      final response = await http.put(
        Uri.parse('${UserSession().baseUrl}/api/image/$imageID/deprecate'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        if (mounted) {
          widget.onDeprecateImage!(imageID);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除成功')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除失败')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除失败')));
    }
  }

  // 构建信息列（右侧/下方内容）
  Widget _buildInfoColumn() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息区域
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基本信息
                  _buildInfoItem('文件名', currentImage.fileName ?? '未命名'),
                  _buildInfoItem('分类', currentImage.category),
                  _buildInfoItem('采集类型', currentImage.collectorType),
                  _buildInfoItem('问题方向', currentImage.questionDirection),
                  _buildInfoItem(
                    '难度',
                    ImageState.getDifficulty(currentImage.difficulty ?? -1),
                  ),
                  _buildInfoItem(
                    '状态',
                    ImageState.getStateText(currentImage.state),
                  ),
                  _buildInfoItem(
                    '创建日期',
                    DateFormat(
                      'yyyy-MM-dd HH:mm:ss',
                    ).format(DateTime.parse(currentImage.created_at)),
                  ),
                  _buildInfoItem(
                    '更新日期',
                    DateFormat(
                      'yyyy-MM-dd HH:mm:ss',
                    ).format(DateTime.parse(currentImage.updated_at)),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          // 删除按钮和分辨率显示
          Row(
            children: [
              if (widget.onImageDeleted != null)
                IconButton(
                  onPressed: () => {_deleteImage(currentImage.imageID)},
                  icon: Icon(Icons.delete),
                  tooltip: '删除',
                  hoverColor: Colors.redAccent,
                ),
              SizedBox(width: 10),
              if (widget.onDeprecateImage != null)
                IconButton(
                  onPressed: () => {_deprecateImage(currentImage.imageID)},
                  icon: Icon(Icons.remove),
                  tooltip: '移除图片',
                ),
              SizedBox(width: 10),
              IconButton(
                onPressed: () => {
                  DownloadHelper.downloadImage(
                    context: context,
                    imgPath: currentImage.path ?? '',
                    imgName: currentImage.fileName ?? '',
                  ),
                },
                icon: Icon(Icons.download),
                tooltip: '下载',
              ),
              SizedBox(width: 10),
              IconButton(
                onPressed: () => {_uploadImage()},
                icon: Icon(Icons.upload),
                tooltip: '上传更新',
              ),
              SizedBox(width: 10),
              IconButton(
                onPressed: () => {_magnifyImage()},
                icon: Icon(Icons.find_in_page),
                tooltip: '放大',
              ),

              // 添加分辨率显示
              if (_imageWidth != null && _imageHeight != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '${_imageWidth}×${_imageHeight}',
                    style: TextStyle(
                      color: (_imageWidth! < 720 || _imageHeight! < 720)
                          ? Colors
                                .red // 小于720时标红
                          : Colors.grey, // 正常显示为灰色
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          // 问题和答案区域
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              // ... 样式不变 ...
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // AI-QA按钮
                        if (widget.onImageOaUpdated != null)
                          IconButton(
                            // onPressed: _isProcessing ? null : _executeAITask,
                            onPressed: () =>
                                widget.onImageOaUpdated!(currentImage),
                            icon: const Icon(Icons.auto_awesome),
                            tooltip: 'AI-QA',
                          ),
                        const SizedBox(width: 20),

                        // 编辑按钮
                        if (!_isEditing) // 仅非编辑模式显示
                          IconButton(
                            onPressed: _startEditing,
                            icon: const Icon(Icons.edit),
                            tooltip: '手动修改',
                          ),
                      ],
                    ),

                    Row(
                      children: [
                        // 标题
                        const Text(
                          '题目内容',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 15),
                        if (widget.onExplanationUpdated != null)
                          IconButton(
                            onPressed: () => {
                              widget.onAnswerUpdated!(currentImage),
                            },
                            icon: Icon(Icons.question_answer),
                            tooltip: '生成答案和解析',
                            color: Colors.blueAccent,
                          ),
                      ],
                    ),

                    // 切换编辑模式
                    if (_isEditing)
                      _buildEditForm()
                    else
                      // 原有问题和答案展示
                      ...currentImage.questions!
                          .map(_buildQuestionAnswer)
                          .toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行（右上角添加关闭按钮）
            Stack(
              children: [
                Center(
                  child: Text(
                    '${currentImage.imageID}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 右上角关闭按钮
                if (widget.onClose != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: widget.onClose,
                    ),
                  ),
              ],
            ),
            // 内容区域
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 700;

                  return isWideScreen
                      ? Row(
                          // 宽屏布局：左图右信息
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 5, child: _buildImageCard()),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: _buildInfoColumn()),
                          ],
                        )
                      : Column(
                          // 窄屏布局：上图下信息
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: _buildImageCard(),
                            ),
                            const SizedBox(height: 20),
                            Expanded(child: _buildInfoColumn()),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  //添加API更新方法
  Future<ImageModel?> _updateImageQA({
    required int imageId,
    required String questionText,
    String? explanation,
    String? textCOT,
    required List<String> answers,
    required int rightAnswerIndex,
  }) async {
    final url = '${UserSession().baseUrl}/api/image/$imageId/qa';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${UserSession().token ?? ''}',
    };
    final body = jsonEncode({
      'difficulty': currentImage.difficulty ?? 0,
      'questionText': questionText,
      'answers': answers,
      'rightAnswerIndex': rightAnswerIndex,
      'explanation': explanation,
      'textCOT': textCOT,
    });

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      //print(response.body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return ImageModel.fromJson(responseData['data']);
      } else {
        throw Exception('更新失败: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
      return null;
    }
  }
}
