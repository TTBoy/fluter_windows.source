import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/user_session.dart';
import 'package:shared_preferences/shared_preferences.dart';


//查找相似图片
///命令行调用查重程序，逐个循环对比一个文件夹内的所有图片，给相似的图片分组显示
///现在的脚本不支持GPU加速，很慢。
class GetSimilarImage extends StatefulWidget {
  const GetSimilarImage({super.key});

  @override
  State<GetSimilarImage> createState() => _GetSimilarImageState();
}

class _GetSimilarImageState extends State<GetSimilarImage> {
  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  String? _selectedFolderPath;

  List<ImageModel> _images = [];

  //分页参数
  int _currentPage = 1;
  int _pageSize = 30;
  bool _isLoading = false;

  List<List<ImageModel>> _similarImageGroups = [];
  int _currentGroupIndex = 0;
  bool _isProcessing = false;

  double clip_threshold = 0.85;
  double resnet_threshold = 0.85;
  int phash_threshold = 30;
  double text_threshold = 0.7;
  int cluster_threshold = 200;
  int threads = 8;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadParameters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('相似查询')),
      body: Column(
        children: [
          _buildTitleSelector(),
          if (_isProcessing) LinearProgressIndicator(),
          Expanded(child: _buildImageGrid()),
          if (_similarImageGroups.isNotEmpty) _buildGroupNavigation(),
        ],
      ),
    );
  }

  // 构建图片网格
  Widget _buildImageGrid() {
    if (_similarImageGroups.isEmpty) {
      return Center(child: Text('暂无相似图片数据'));
    }

    if (_currentGroupIndex >= _similarImageGroups.length) {
      return Center(child: Text('分组索引超出范围'));
    }

    final currentGroup = _similarImageGroups[_currentGroupIndex];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      padding: EdgeInsets.all(8),
      itemCount: currentGroup.length,
      itemBuilder: (context, index) {
        return _buildGridItem(currentGroup[index]);
      },
    );
  }

  // 构建分组导航
  Widget _buildGroupNavigation() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _currentGroupIndex > 0 ? _goToPreviousGroup : null,
          ),
          Text('分组 ${_currentGroupIndex + 1} / ${_similarImageGroups.length}'),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: _currentGroupIndex < _similarImageGroups.length - 1
                ? _goToNextGroup
                : null,
          ),
        ],
      ),
    );
  }

  void _goToPreviousGroup() {
    setState(() {
      if (_currentGroupIndex > 0) {
        _currentGroupIndex--;
      }
    });
  }

  void _goToNextGroup() {
    setState(() {
      if (_currentGroupIndex < _similarImageGroups.length - 1) {
        _currentGroupIndex++;
      }
    });
  }

  // 选择文件夹
  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _selectedFolderPath = selectedDirectory;
      });
    }
  }

  // 执行查询操作
  Future<void> _executeQuery() async {
    if (_selectedFolderPath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请先选择文件夹')));
      return;
    }

    setState(() {
      _isProcessing = true;
      _similarImageGroups = [];
      _currentGroupIndex = 0;
    });

    try {
      // 0. 先删除文件夹内的所有图片文件
      await _deleteAllImagesInFolder();

      // 1. 下载图片
      await _downloadAllImages();

      // 2. 运行Python脚本分析重复图片
      final duplicateGroups = await _runPythonScriptAndParse();

      // 3. 获取重复图片信息
      for (var group in duplicateGroups) {
        await _fetchImagesByName(group);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败: $e')));
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 显示参数设置对话框
  Future<void> _loadParameters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      clip_threshold = prefs.getDouble('clip_threshold') ?? 0.75;
      resnet_threshold = prefs.getDouble('resnet_threshold') ?? 0.85;
      phash_threshold = prefs.getInt('phash_threshold') ?? 20;
      text_threshold = prefs.getDouble('text_threshold') ?? 0.7;
      cluster_threshold = prefs.getInt('cluster_threshold') ?? 100;
      threads = prefs.getInt('threads') ?? 4;
    });
  }

  Future<void> _saveParameters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('clip_threshold', clip_threshold);
    await prefs.setDouble('resnet_threshold', resnet_threshold);
    await prefs.setInt('phash_threshold', phash_threshold);
    await prefs.setDouble('text_threshold', text_threshold);
    await prefs.setInt('cluster_threshold', cluster_threshold);
    await prefs.setInt('threads', threads);
  }

  void _showParameterSettingsDialog() {
    // 创建临时变量存储当前设置
    double tempClipThreshold = clip_threshold;
    double tempResnetThreshold = resnet_threshold;
    int tempPhashThreshold = phash_threshold;
    double tempTextThreshold = text_threshold;
    int tempClusterThreshold = cluster_threshold;
    int tempThreads = threads;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('相似度参数设置'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clip 阈值
                    _buildDecimalParameterSlider(
                      'Clip 阈值',
                      tempClipThreshold,
                      0.0,
                      1.0,
                      (value) => setState(() => tempClipThreshold = value),
                    ),

                    // ResNet 阈值
                    _buildDecimalParameterSlider(
                      'ResNet 阈值',
                      tempResnetThreshold,
                      0.0,
                      1.0,
                      (value) => setState(() => tempResnetThreshold = value),
                    ),

                    // PHash 阈值
                    _buildIntegerParameterSlider(
                      'PHash 阈值',
                      tempPhashThreshold,
                      0,
                      100,
                      (value) => setState(() => tempPhashThreshold = value),
                    ),

                    // 文本阈值
                    _buildDecimalParameterSlider(
                      '文本阈值',
                      tempTextThreshold,
                      0.0,
                      1.0,
                      (value) => setState(() => tempTextThreshold = value),
                    ),

                    // 聚类阈值
                    _buildIntegerParameterSlider(
                      '聚类阈值',
                      tempClusterThreshold,
                      0,
                      500,
                      (value) => setState(() => tempClusterThreshold = value),
                    ),

                    // 线程数
                    _buildIntegerParameterSlider(
                      '线程数',
                      tempThreads,
                      1,
                      16,
                      (value) => setState(() => tempThreads = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      clip_threshold = tempClipThreshold;
                      resnet_threshold = tempResnetThreshold;
                      phash_threshold = tempPhashThreshold;
                      text_threshold = tempTextThreshold;
                      cluster_threshold = tempClusterThreshold;
                      threads = tempThreads;
                    });
                    _saveParameters();

                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('参数已更新')));
                  },
                  child: Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 构建小数参数滑块控件（精确到小数点后两位）
  Widget _buildDecimalParameterSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(2)}'),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min) ~/ 0.01, // 每0.01一个步长
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // 构建整数参数滑块控件
  Widget _buildIntegerParameterSlider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value'),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: value.toString(),
            onChanged: (double value) => onChanged(value.toInt()),
          ),
        ],
      ),
    );
  }

  // 删除文件夹内的所有图片文件
  Future<void> _deleteAllImagesInFolder() async {
    if (_selectedFolderPath == null) return;

    final dir = Directory(_selectedFolderPath!);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      return;
    }

    try {
      // 获取文件夹中的所有文件
      final files = dir.listSync();

      // 定义常见的图片文件扩展名
      const imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.tiff',
        '.webp',
      ];

      // 删除所有图片文件
      for (var file in files) {
        if (file is File) {
          final extension = path.extension(file.path).toLowerCase();
          if (imageExtensions.contains(extension)) {
            file.deleteSync();
          }
        }
      }

      print('已删除文件夹中的所有图片文件');
    } catch (e) {
      print('删除图片文件时出错: $e');
      // 可以选择抛出异常或只是记录错误
    }
  }

  // 下载所有图片
  Future<void> _downloadAllImages() async {
    int page = 1;
    bool hasMore = true;

    // 清空目标文件夹
    final dir = Directory(_selectedFolderPath!);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    while (hasMore && !_isLoading) {
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'pageSize': _pageSize.toString(),
      };

      if (_selectedCategoryId != null) {
        final category = _categories.firstWhere(
          (c) => c['id'] == _selectedCategoryId,
          orElse: () => {'name': ''},
        );
        queryParams['category'] = category['name'];
      }

      if (_selectedCollectorTypeId != null) {
        final collectorType = _collectorTypes.firstWhere(
          (c) => c['id'] == _selectedCollectorTypeId,
          orElse: () => {'name': ''},
        );
        queryParams['collector_type'] = collectorType['name'];
      }

      if (_selectedQuestionDirectionId != null) {
        final questionDirection = _questionDirections.firstWhere(
          (q) => q['id'] == _selectedQuestionDirectionId,
          orElse: () => {'name': ''},
        );
        queryParams['question_direction'] = questionDirection['name'];
      }

      final uri = Uri.parse(
        '${UserSession().baseUrl}/api/image',
      ).replace(queryParameters: queryParams);

      try {
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final pagination = data['data'];
          final imageData = pagination['data'] as List;

          // 下载本页所有图片
          for (var imgData in imageData) {
            final image = ImageModel.fromJson(imgData);
            if (image.path != null && image.path!.isNotEmpty) {
              await _downloadImage(image);
            }
          }

          // 检查是否还有更多页
          hasMore = imageData.length == _pageSize;
          page++;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('下载图片失败: $e');
      }
    }
  }

  // 下载单张图片
  Future<void> _downloadImage(ImageModel image) async {
    try {
      final imageUrl = '${UserSession().baseUrl}/${image.path}';
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
      );

      if (response.statusCode == 200) {
        final fileName = path.basename(image.path!);
        final file = File(path.join(_selectedFolderPath!, fileName));
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      print('下载图片失败: ${image.path} - $e');
    }
  }

  // 运行Python脚本并解析结果
  Future<List<List<String>>> _runPythonScriptAndParse() async {
    final script = path.join('${UserSession().getRepetPath}', 'script.exe');
    // 构建参数列表
    final args = [
      _selectedFolderPath!,
      '--clip_threshold',
      clip_threshold.toString(),
      '--resnet_threshold',
      resnet_threshold.toString(),
      '--phash_threshold',
      phash_threshold.toString(),
      '--text_threshold',
      text_threshold.toString(),
      '--cluster_threshold',
      cluster_threshold.toString(),
      '--threads',
      threads.toString(),
    ];
    // final result = await Process.run(script, [_selectedFolderPath!]);
    final result = await Process.run(script, args);

    if (result.exitCode != 0) {
      throw Exception('Python脚本执行失败: ${result.stderr}');
    }

    final output = result.stdout.toString().trim();

    // 尝试从输出中提取 JSON 部分
    String jsonOutput = output;

    // 方法1: 查找 JSON 数组的开始和结束
    final jsonStart = output.indexOf('[');
    final jsonEnd = output.lastIndexOf(']');

    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      jsonOutput = output.substring(jsonStart, jsonEnd + 1);
    } else {
      // 方法2: 尝试逐行解析，找到有效的 JSON
      final lines = output.split('\n');
      for (var line in lines.reversed) {
        line = line.trim();
        if (line.startsWith('[') && line.endsWith(']')) {
          jsonOutput = line;
          break;
        }
      }
    }

    try {
      final List<dynamic> parsed = jsonDecode(jsonOutput);
      print(jsonOutput);
      return parsed.map<List<String>>((group) {
        return List<String>.from(group);
      }).toList();
    } catch (e) {
      // 如果仍然失败，尝试更宽松的解析方法
      try {
        // 尝试清理可能的非 JSON 字符
        final cleanedOutput = jsonOutput
            .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // 移除非 ASCII 字符
            .replaceAll(RegExp(r'\s+'), ' ') // 规范化空格
            .trim();

        final List<dynamic> parsed = jsonDecode(cleanedOutput);
        return parsed.map<List<String>>((group) {
          return List<String>.from(group);
        }).toList();
      } catch (e2) {
        // 如果所有方法都失败，记录原始输出并抛出异常
        print('原始输出: $output');
        print('尝试解析的 JSON: $jsonOutput');
        throw Exception('解析Python脚本输出失败: $e2\n原始输出: $output');
      }
    }
  }

  //根据文件名和类目查询图片
  Future<void> _fetchImagesByName(List<String> imageNames) async {
    if (imageNames.isEmpty) return;

    String categoryName = '';
    if (_selectedCategoryId != null) {
      final category = _categories.firstWhere(
        (c) => c['id'] == _selectedCategoryId,
        orElse: () => {'name': ''},
      );
      categoryName = category['name'];
    }

    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/image/search'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'category': categoryName, 'fileNames': imageNames}),
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final imageData = data['data'] as List;
        setState(() {
          if (imageData.isNotEmpty) {
            _similarImageGroups.add(
              imageData.map((img) => ImageModel.fromJson(img)).toList(),
            );
          }
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取图片信息失败: $e');
    }
  }

  // 处理图片更新回调
  // 处理图片更新回调
  void _handleImageUpdated(ImageModel updatedImage) {
    setState(() {
      // 遍历所有相似图片分组
      for (
        var groupIndex = 0;
        groupIndex < _similarImageGroups.length;
        groupIndex++
      ) {
        final group = _similarImageGroups[groupIndex];

        // 在当前分组中查找需要更新的图片
        final imageIndex = group.indexWhere(
          (img) => img.imageID == updatedImage.imageID,
        );
        if (imageIndex != -1) {
          // 更新图片信息
          group[imageIndex] = updatedImage;

          // 更新分组引用
          _similarImageGroups[groupIndex] = List.from(group);
          break;
        }
      }
    });
  }

  // 处理图片删除回调
  void _handleImageDeleted(int imageID) {
    setState(() {
      // 遍历所有相似图片分组
      for (
        var groupIndex = 0;
        groupIndex < _similarImageGroups.length;
        groupIndex++
      ) {
        final group = _similarImageGroups[groupIndex];

        // 在当前分组中查找需要删除的图片
        final imageIndex = group.indexWhere((img) => img.imageID == imageID);
        if (imageIndex != -1) {
          // 从分组中移除图片
          group.removeAt(imageIndex);

          // 如果分组中图片数量少于2，移除整个分组（不再构成相似）
          if (group.length < 2) {
            _similarImageGroups.removeAt(groupIndex);

            // 调整当前分组索引
            if (_currentGroupIndex >= _similarImageGroups.length) {
              _currentGroupIndex = _similarImageGroups.length > 0
                  ? _similarImageGroups.length - 1
                  : 0;
            }
          } else {
            // 更新分组引用
            _similarImageGroups[groupIndex] = List.from(group);
          }

          break;
        }
      }
    });

    // 关闭图片详情弹窗
    Navigator.pop(context);
  }

  // 打开图片详情弹窗
  void _openImageDetail(ImageModel image) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ImageDetail(
            image: image,
            onImageUpdated: _handleImageUpdated,
            onClose: () => Navigator.pop(context),
            onImageDeleted: _handleImageDeleted,
          ),
        );
      },
    );
  }

  Widget _buildGridItem(ImageModel image) {
    final firstQuestion = image.questions?.isNotEmpty == true
        ? image.questions?.first
        : null;

    return GestureDetector(
      onLongPress: () => {},
      onTap: () {
        _openImageDetail(image);
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 图片显示
                    image.path?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: '${UserSession().baseUrl}/${image.path}',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Center(child: Icon(Icons.error)),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),

                    // 图片状态标签（悬浮在右上角）
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildImageStatusBadge(image.state),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // 图片信息
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      '#${image.imageID}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  //快捷AI更新QA按钮
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: IconButton(
                      onPressed: () => {},
                      icon: Icon(Icons.auto_awesome),
                      iconSize: 20,
                      tooltip: 'AI-QA',
                    ),
                  ),
                ],
              ),

              // 问题摘要（显示第一个问题）
              if (firstQuestion != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 问题文本
                      Text(
                        firstQuestion.questionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),

                      const SizedBox(height: 6),

                      // 答案选项显示
                      _buildAnswerIndicators(firstQuestion),
                    ],
                  ),
                ),
              ],
              Text('${image.category}'),
            ],
          ),
        ],
      ),
    );
  }

  // 图片状态标签
  Widget _buildImageStatusBadge(int state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ImageState.getStateColor(state).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ImageState.getStateColor(state)),
      ),
      child: Text(
        ImageState.getStateText(state),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 答案选项指示器
  Widget _buildAnswerIndicators(QuestionModel question) {
    // 找到正确答案
    final rightAnswerId = question.rightAnswer.answerID;

    return Wrap(
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
              color: isCorrect
                  ? Colors.green
                  : Colors.grey.shade300, // 使用 .shade 确保非空
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
    );
  }

  Widget _buildTitleSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCategoryDropdown(),
          SizedBox(width: 20),
          _buildCollectorTypeDropdown(),
          SizedBox(width: 20),
          _buildQuestionDirectionDropdown(),
          SizedBox(width: 20),
          IconButton(
            onPressed: () => {_pickFolder()},
            icon: Icon(Icons.folder),
            tooltip: '选择文件夹',
          ),
          SizedBox(width: 20),
          SizedBox(
            width: 150,
            height: 45,
            child: ElevatedButton(
              onPressed: () => {_executeQuery()},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('查询', style: TextStyle(fontSize: 16)),
            ),
          ),
          SizedBox(width: 20),
          IconButton(
            onPressed: _showParameterSettingsDialog,
            icon: Icon(Icons.settings),
            tooltip: '参数设置',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return _buildLevelDropdown(
      value: _selectedCategoryId,
      options: _categories.map((e) => e['id'] as String).toList(),
      hint: '采集类目',
      displayValues: _categories.fold({}, (map, item) {
        map[item['id']] = item['name'];
        return map;
      }),
      onChanged: (newValue) {
        setState(() {
          _selectedCategoryId = newValue;
        });
        _fetchCollectorTypes(newValue);
      },
    );
  }

  Widget _buildCollectorTypeDropdown() {
    return _buildLevelDropdown(
      value: _selectedCollectorTypeId,
      options: _collectorTypes.map((e) => e['id'] as String).toList(),
      hint: '采集类型',
      displayValues: _collectorTypes.fold({}, (map, item) {
        map[item['id']] = item['name'];
        return map;
      }),
      onChanged: (newValue) {
        setState(() {
          _selectedCollectorTypeId = newValue;
        });
        _fetchQuestionDirections(newValue);
      },
      enabled: _selectedCategoryId != null,
    );
  }

  Widget _buildQuestionDirectionDropdown() {
    return _buildLevelDropdown(
      value: _selectedQuestionDirectionId,
      options: _questionDirections.map((e) => e['id'] as String).toList(),
      hint: '问题方向',
      displayValues: _questionDirections.fold({}, (map, item) {
        map[item['id']] = item['name'];
        return map;
      }),
      onChanged: (newValue) {
        setState(() {
          _selectedQuestionDirectionId = newValue;
        });
      },
      enabled: _selectedCollectorTypeId != null,
    );
  }

  // 普通下拉框 - 显式使用 String?
  Widget _buildLevelDropdown({
    required String? value,
    required List<String> options,
    required String hint,
    required Map<String, String> displayValues,
    bool enabled = true,
    ValueChanged<String?>? onChanged,
  }) {
    // 修复：直接构建菜单项列表
    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他选项
      ...options.map((id) {
        return DropdownMenuItem<String?>(
          value: id,
          child: Text(
            displayValues[id] ?? '未知',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    ];

    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
          enabled: enabled,
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  // 通用API请求方法
  Future<List<dynamic>> _fetchData(String endpoint) async {
    final response = await http.get(
      Uri.parse('${UserSession().baseUrl}$endpoint'),
      headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as List<dynamic>;
    } else {
      throw Exception('Failed to load data from $endpoint');
    }
  }

  // 获取所有类目
  Future<void> _fetchCategories() async {
    try {
      final categories = await _fetchData('/api/category/');
      setState(() {
        _categories = categories.map<Map<String, dynamic>>((item) {
          return {
            'id': item['categoryID'].toString(),
            'name': item['categoryName'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // 根据类目ID获取采集类型 - 不清除用户选择
  Future<void> _fetchCollectorTypes(String? categoryId) async {
    if (categoryId == null) {
      setState(() {
        _collectorTypes = [];
        _selectedCollectorTypeId = null;
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
        // 不再清除用户选择 - 保持独立
      });
      return;
    }

    try {
      final collectorTypes = await _fetchData(
        '/api/category/$categoryId/collector-types',
      );
      setState(() {
        _collectorTypes = collectorTypes.map<Map<String, dynamic>>((item) {
          return {
            'id': item['collectorTypeID'].toString(),
            'name': item['collectorTypeName'],
          };
        }).toList();
        _selectedCollectorTypeId = null;
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
        // 不再清除用户选择 - 保持独立
      });
    } catch (e) {
      print('Error fetching collector types: $e');
    }
  }

  // 根据采集类型ID获取问题方向
  Future<void> _fetchQuestionDirections(String? collectorTypeId) async {
    if (collectorTypeId == null) {
      setState(() {
        _questionDirections = [];
        _selectedQuestionDirectionId = null;
      });
      return;
    }

    try {
      final questionDirections = await _fetchData(
        '/api/category/collector-types/$collectorTypeId/question-directions',
      );
      setState(() {
        _questionDirections = questionDirections.map<Map<String, dynamic>>((
          item,
        ) {
          return {
            'id': item['questionDirectionID'].toString(),
            'name': item['questionDirectionName'],
          };
        }).toList();
        _selectedQuestionDirectionId = null;
      });
    } catch (e) {
      print('Error fetching question directions: $e');
    }
  }
}
