import 'dart:collection';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/answer_model.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/user_session.dart';


///传入[workID]显示Work详情
///
class WorkDetailScreen extends StatefulWidget {
  final int workID;

  const WorkDetailScreen({super.key, required this.workID});

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  WorkModel? _work;
  List<ImageModel> _images = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String _errorMessage = '';
  int _columnCount = 4; // 默认4列

  Set<int> _processingImageIDs = {}; // 记录正在处理AI的图片ID

  Set<int> _selectedImageIDs = {}; // 存储选中的图片ID
  bool _isInSelectionMode = false; // 是否处于多选模式

  //难度选择状态
  int? _selectedDifficulty;
  final Map<int, String> difficultyOptions = {0: "简单", 1: "中等", 2: "困难"};

  @override
  void initState() {
    super.initState();
    _fetchWorkDetails();
  }

  // 列数切换方法
  void _toggleColumnCount() {
    setState(() {
      _columnCount = _columnCount >= 8 ? 4 : _columnCount + 1;
    });
  }

  Future<void> _fetchWorkDetails() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final url = Uri.parse(
        '${UserSession().baseUrl}/api/works/${widget.workID}/details?page=$_currentPage&limit=10',
      );

      final headers = {
        'Authorization': 'Bearer ${UserSession().token}',
        'Content-Type': 'application/json',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200) {
          final workData = data['data'];

          setState(() {
            // 解析工作信息
            _work = WorkModel.fromJson(workData['work']);

            // 解析图片列表
            final imageData = workData['images'];
            final pagination = imageData['pagination'];

            _currentPage = pagination['currentPage'];
            _totalPages = pagination['totalPages'];

            final newImages = (imageData['data'] as List)
                .map((imgJson) => ImageModel.fromJson(imgJson))
                .toList();

            // 新增分页加载，追加图片
            _images.addAll(newImages);
            _hasMore = _currentPage < _totalPages;
            // if(_currentPage==_totalPages){
            //   _isLoading=false;
            // }
          });
        } else {
          throw Exception('API错误: ${data['message']}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载数据失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  // 加载更多图片
  void _loadMoreImages() {
    if (_hasMore && !_isLoading) {
      _currentPage++;
      _fetchWorkDetails();
    }
  }

  // 处理图片更新回调
  void _handleImageUpdated(ImageModel updatedImage) {
    setState(() {
      // 找到并更新图片列表中的对应图片
      final index = _images.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _images[index] = updatedImage;
      }
    });
  }

  //处理图片删除
  void _handleImageDeleted(int imageID) {
    setState(() {
      final index = _images.indexWhere((img) => img.imageID == imageID);
      if (index != -1) {
        _images.removeAt(index); // 通过索引删除元素
      }
    });
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
            onImageOaUpdated: _handleImageQaUpadted,
            onAnswerUpdated: _handleAnswerUpdated,
            onExplanationUpdated: _handleExplanationUpdated,
          ),
        );
      },
    );
  }

  //显示打回原因和备注弹窗
  void _openReturnReasonAndRemark() {
    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 10),
              const Text(
                '打回详情',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_work!.returnReason != null &&
                  _work!.returnReason!.isNotEmpty) ...[
                const Text(
                  '打回原因：',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _work!.returnReason!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (_work!.remark != null && _work!.remark!.isNotEmpty) ...[
                const Text(
                  '备注说明：',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    _work!.remark!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              if ((_work!.returnReason == null ||
                      _work!.returnReason!.isEmpty) &&
                  (_work!.remark == null || _work!.remark!.isEmpty))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '暂无打回信息',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work #${widget.workID}'),
        actions: [
          _buildIntLevelDropdown(
            // 使用新的整数版本组件
            value: _selectedDifficulty,
            options: difficultyOptions.keys.toList(),
            hint: '难度',
            displayValues: difficultyOptions,
            onChanged: (newValue) {
              setState(() {
                _selectedDifficulty = newValue;
              });
            },
          ),
          SizedBox(width: 20),
          IconButton(
            onPressed: () => {_addImages(widget.workID)},
            icon: Icon(Icons.upload),
            tooltip: '添加图片',
          ),
          SizedBox(width: 15),
          IconButton(
            onPressed: () => {_openReturnReasonAndRemark()},
            icon: Icon(Icons.tips_and_updates),
            tooltip: '打回信息',
          ),
          SizedBox(width: 20),
          if (_isInSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectedImageIDs.length == _images.length
                  ? _deselectAllImages
                  : _selectAllImages,
              tooltip: _selectedImageIDs.length == _images.length
                  ? '取消全选'
                  : '全选',
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _batchProcessImages,
              tooltip: '批量处理',
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _deselectAllImages,
              tooltip: '退出多选',
            ),
          ] else if (_images.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _isInSelectionMode = true),
              tooltip: '多选模式',
            ),
          ],
          SizedBox(width: 20),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _toggleColumnCount,
        tooltip: '切换列数 ($_columnCount)',
        child: Text('$_columnCount列'),
      ),
    );
  }

  //从本地文件夹选择上传图片文件
  Future<void> _addImages(int workID) async {
    try {
      // 打开Windows文件选择器，选择多个图片文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消了选择
        return;
      }

      // 获取所有选中的文件
      List<File> files = result.paths.map((path) => File(path!)).toList();

      // 显示上传进度
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('开始上传 ${files.length} 个文件...')));

      // 循环上传每个文件
      for (int i = 0; i < files.length; i++) {
        File file = files[i];
        String fileName = file.path.split('/').last;

        // 创建多部分请求
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${UserSession().baseUrl}/api/image/work'),
        );

        // 添加授权头
        request.headers['Authorization'] = 'Bearer ${UserSession().token}';

        // 添加workID字段
        request.fields['workID'] = workID.toString();

        // 添加文件字段
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: fileName,
            contentType: MediaType('image', fileName.split('.').last),
          ),
        );

        // 发送请求
        var response = await request.send();

        String responseBody = await response.stream.bytesToString();

        // 检查响应状态
        if (response.statusCode == 200) {
          print('文件 $fileName 上传成功');
        } else if (response.statusCode == 400) {
          print('文件 $fileName 上传失败: ${responseBody}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${jsonDecode(responseBody)['message']}')),
          );
        }
      }
      setState(() {
        _images.clear();
        _currentPage = 1;
        _totalPages = 1;
        _isLoading = false;
        _fetchWorkDetails();
      });

      // 所有文件上传完成提示
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('所有文件上传完成')));
    } catch (e) {
      print('上传失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  // int 类型的下拉框
  Widget _buildIntLevelDropdown({
    required int? value,
    required List<int> options,
    required String hint,
    required Map<int, String> displayValues,
    bool enabled = true,
    ValueChanged<int?>? onChanged,
  }) {
    // 构建菜单项
    final items = [
      DropdownMenuItem<int?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      ...options.map((id) {
        return DropdownMenuItem<int?>(
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
      child: DropdownButtonFormField<int?>(
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

  Widget _buildBody() {
    if (_isLoading && _images.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchWorkDetails,
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    if (_work == null) {
      return const Center(child: Text('加载工作信息失败'));
    }

    return Column(
      children: [
        // 网格布局
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              // 滚动到底部加载更多
              if (scrollInfo.metrics.pixels ==
                  scrollInfo.metrics.maxScrollExtent) {
                _loadMoreImages();
              }
              return true;
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnCount,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _images.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _buildLoadMoreIndicator();
                }
                return GestureDetector(
                  key: ValueKey(_images[index].imageID),
                  onTap: () => _openImageDetail(_images[index]),
                  child: _buildGridItem(_images[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  //AI生成QA
  Future<void> _executeAITask(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
    }
    try {
      // 1. 调用AI服务
      final qa = await AiService.getQA(
        image,
        questionDifficulty: _selectedDifficulty ?? 0,
      );
      if (qa == null) throw Exception('AI服务返回空数据');

      debugPrint('AI生成结果: ${qa.toString()}');

      // 2. 更新到后端API
      final updatedImage = await _updateImageQA(
        image: image,
        questionText: qa.question,
        answers: qa.options,
        rightAnswerIndex: qa.correctAnswer,
        explanation: qa.explanation,
        textCOT: qa.textCOT,
      );

      setState(() {
        // 找到并更新图片列表中的对应图片
        final index = _images.indexWhere(
          (img) => img.imageID == updatedImage!.imageID,
        );
        if (index != -1) {
          _images[index] = updatedImage!;
        }
      });

      if (updatedImage == null) throw Exception('图片更新失败');
      // 4. 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片${updatedImage.imageID}AI处理完成')),
      );
    } catch (e, stackTrace) {
      debugPrint('AI处理错误: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理失败: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingImageIDs.remove(image.imageID);
        });
      }
    }
  }

  //根据问题生成答案和解析等
  Future<void> _executeAIAnswerAnexplanation(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
      try {
        final answers = await AiService.getAnswer(image);
        if (answers == null) throw Exception('AI返回空数据');
        final updatedImage = await _updateImageQA(
          image: image,
          questionText: image.questions!.first.questionText,
          answers: answers.answers,
          rightAnswerIndex: answers.rightAnswerIndex,
          explanation: answers.explanation,
          textCOT: answers.COT,
        );
        setState(() {
          final index = _images.indexWhere(
            (img) => img.imageID == updatedImage!.imageID,
          );
          if (index != -1) {
            _images[index] = updatedImage!;
          }
        });
        if (updatedImage == null) throw Exception('图片更新失败');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功生成答案和解析')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('答案生成失败$e')));
      } finally {
        if (mounted) {
          setState(() {
            _processingImageIDs.remove(image.imageID);
          });
        }
      }
    }
  }

  //寻找正确答案索引
  int _findRightAnswerIndex(List<AnswerModel> answers, int rightAnswerId) {
    for (int i = 0; i < answers.length; i++) {
      if (answers[i].answerID == rightAnswerId) {
        return i;
      }
    }
    return -1; // 未找到匹配项，返回-1
  }

  //根据问题和答案生成解析和解题步骤
  Future<void> _executeAIExplanationCOT(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
      try {
        final explanationCot = await AiService.getExplanationAndCOT(image);
        if (explanationCot == null) throw Exception('AI返回空数据');
        // QuestionModel

        final updatedImage = await _updateImageQA(
          image: image,
          questionText: image.questions!.first.questionText,
          answers: image.questions!.first.answers
              .map((answer) => answer.answerText)
              .toList(),
          rightAnswerIndex: _findRightAnswerIndex(
            image.questions!.first.answers,
            image.questions!.first.rightAnswer.answerID,
          ),
          explanation: explanationCot.explanation,
          textCOT: explanationCot.COT,
        );
        setState(() {
          final index = _images.indexWhere(
            (img) => img.imageID == updatedImage!.imageID,
          );
          if (index != -1) {
            _images[index] = updatedImage!;
          }
        });
        if (updatedImage == null) throw Exception('图片更新失败');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('成功生成答案和解析')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('答案生成失败$e')));
      } finally {
        if (mounted) {
          setState(() {
            _processingImageIDs.remove(image.imageID);
          });
        }
      }
    }
  }

  // 网格项组件
  Widget _buildGridItem(ImageModel image) {
    final firstQuestion = image.questions?.isNotEmpty == true
        ? image.questions?.first
        : null;
    final bool isProcessing = _processingImageIDs.contains(image.imageID);
    final bool isSelected = _selectedImageIDs.contains(image.imageID);

    return Container(
      key: ValueKey(image.imageID),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onLongPress: () => {
          setState(() {
            _isInSelectionMode = true;
            _toggleImageSelection(image.imageID);
          }),
        },
        onTap: () {
          if (_isInSelectionMode) {
            setState(() => _toggleImageSelection(image.imageID));
          } else {
            _openImageDetail(image);
          }
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
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl:
                                    '${UserSession().baseUrl}/${image.path}',
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
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.image_not_supported),
                              ),
                            ),

                      // 图片状态标签（悬浮在左上角）
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildImageStatusBadge(image.state),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 图片信息
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '#${image.imageID}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 快捷AI更新QA按钮
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        onPressed: () => {_executeAITask(image)},
                        icon: const Icon(Icons.auto_awesome),
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
              ],
            ),

            // 多选框（悬浮在右上角）
            if (_isInSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (value) => setState(() {
                      _toggleImageSelection(image.imageID);
                    }),
                  ),
                ),
              ),

            // 处理中遮罩
            if (isProcessing)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 添加辅助方法
  void _toggleImageSelection(int imageID) {
    if (_selectedImageIDs.contains(imageID)) {
      _selectedImageIDs.remove(imageID);
    } else {
      _selectedImageIDs.add(imageID);
    }

    // 如果没有选中任何图片，退出多选模式
    if (_selectedImageIDs.isEmpty) {
      _isInSelectionMode = false;
    }
  }
 
  //全选所有图片
  void _selectAllImages() {
    setState(() {
      _selectedImageIDs = Set<int>.from(_images.map((img) => img.imageID));
      _isInSelectionMode = true;
    });
  }

  //取消全选
  void _deselectAllImages() {
    setState(() {
      _selectedImageIDs.clear();
      _isInSelectionMode = false;
    });
  }

  //批量处理图片
  Future<void> _batchProcessImages() async {
    if (_selectedImageIDs.isEmpty) return;

    // 确认对话框
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认批量处理'),
            content: Text('确定要批量处理选中的 ${_selectedImageIDs.length} 张图片吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始处理'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // 复制一份选中的图片ID，防止在处理过程中修改
    final imagesToProcess = List<int>.from(_selectedImageIDs);
    final totalCount = imagesToProcess.length;

    // 添加到处理队列并清空选择
    setState(() {
      _processingImageIDs.addAll(imagesToProcess);
      _deselectAllImages();
    });

    int processedCount = 0;

    // 使用队列控制并发数量
    final queue = Queue<Future>();
    const maxConcurrency = 8; // 最大并发数

    for (final imageID in imagesToProcess) {
      while (queue.length >= maxConcurrency) {
        await Future.any(queue);
      }

      final image = _images.firstWhere((img) => img.imageID == imageID);

      // 先声明 task 变量
      Future task = _executeAITask(image);

      // 将任务添加到队列
      queue.add(task);

      // 使用 task 变量
      task
          .then((_) {
            processedCount++;
            if (processedCount % 5 == 0 || processedCount == totalCount) {
              // 每处理8张或全部完成时更新进度
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("处理进度: $processedCount/$totalCount")),
                );
              }
            }
            queue.remove(task);
          })
          .catchError((error) {
            queue.remove(task);
          });
    }

    await Future.wait(queue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("批量处理完成! 成功: $processedCount/$totalCount")),
      );
    }
  }

  // 答案选项指示器
  Widget _buildAnswerIndicators(QuestionModel question) {
    // 找到正确答案
    final rightAnswerId = question.rightAnswer.answerID;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxHeight;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: question.answers.asMap().entries.map((entry) {
            final index = entry.key;
            final answer = entry.value;
            final isCorrect = answer.answerID == rightAnswerId;
            final letter = String.fromCharCode(65 + index); // A, B, C...

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth * 0.45,
                minWidth: 45,
              ),
              child: Container(
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
                ),
              ),
            );
          }).toList(),
        );
      },
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

  Future<ImageModel?> _updateImageQA({
    required ImageModel image,
    required String questionText,
    String? explanation,
    String? textCOT,
    required List<String> answers,
    required int rightAnswerIndex,
  }) async {
    final url = '${UserSession().baseUrl}/api/image/${image.imageID}/qa';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${UserSession().token ?? ''}',
    };
    final body = jsonEncode({
      'difficulty': image.difficulty ?? 0,
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

      print(response.body);

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

  // 加载更多指示器
  Widget _buildLoadMoreIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _hasMore
            ? const CircularProgressIndicator()
            : const Text('没有更多图片了', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  void _handleImageQaUpadted(ImageModel currentImage) {
    _executeAITask(currentImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
  }

  void _handleAnswerUpdated(ImageModel updatedImage) {
    _executeAIAnswerAnexplanation(updatedImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
  }

  void _handleExplanationUpdated(ImageModel updatedImage) {
    _executeAIExplanationCOT(updatedImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
  }
}
