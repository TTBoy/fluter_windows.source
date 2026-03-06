import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/tools/work_state.dart';
import 'package:qa_imageprocess/user_session.dart';


///质检界面
///传入[workID]后获取Work详情
///
class Review extends StatefulWidget {
  final int workID;
  const Review({super.key, required this.workID});

  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  WorkModel? _work;
  List<ImageModel> _images = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String _errorMessage = '';

  // 当前选中的图片
  int? _selectedImageId;

  // 多选模式相关
  Set<int> _processingImageIDs = {};
  Set<int> _selectedImageIDs = {};
  bool _isInSelectionMode = false;

  // 全选状态变量
  bool _isAllSelected = false;
  //打回原因和备注
  TextEditingController _returnReasonController = TextEditingController();
  TextEditingController _remarkController = TextEditingController();

  TextEditingController _passReasonController = TextEditingController();
  TextEditingController _passRemarkController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _fetchWorkDetails();
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
            _work = WorkModel.fromJson(workData['work']);
            final imageData = workData['images'];
            final pagination = imageData['pagination'];

            _currentPage = pagination['currentPage'];
            _totalPages = pagination['totalPages'];

            final newImages = (imageData['data'] as List)
                .map((imgJson) => ImageModel.fromJson(imgJson))
                .toList();

            _images.addAll(newImages);
            _hasMore = _currentPage < _totalPages;

            // 默认选中第一张图片
            if (_images.isNotEmpty && _selectedImageId == null) {
              _selectedImageId = _images.first.imageID;
            }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_work?.workID.toString() ?? '质检任务'),
        actions: [
          if (_work != null) ...[
            // 通过按钮
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              tooltip: '通过任务',
              onPressed: _showPassWorkDialog,
            ),
            // 打回按钮
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              tooltip: '打回任务',
              onPressed: _showReturnWorkDialog,
            ),
          ],
        ],
      ),
      body: _errorMessage.isNotEmpty
          ? Center(
              child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
            )
          : _isLoading && _images.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // 左侧图片列表
                SizedBox(width: 300, child: _buildImageList()),
                // 分隔线
                const VerticalDivider(width: 1, thickness: 1),
                // 右侧图片详情
                Expanded(
                  child: _selectedImageId != null
                      ? _buildImageDetail()
                      : const Center(child: Text('请选择一张图片')),
                ),
              ],
            ),
    );
  }

  // 构建图片列表
  Widget _buildImageList() {
    return Column(
      children: [
        // 列表头部
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[200],
          child: Row(
            children: [
              const Text('图片列表', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_isInSelectionMode) ...[
                IconButton(
                  icon: Icon(
                    _isAllSelected ? Icons.deselect : Icons.select_all,
                  ),
                  tooltip: _isAllSelected ? '取消全选' : '全选',
                  onPressed: () {
                    setState(() {
                      if (_isAllSelected) {
                        _selectedImageIDs.clear();
                      } else {
                        _selectedImageIDs = _images
                            .map((img) => img.imageID)
                            .toSet();
                      }
                      _isAllSelected = !_isAllSelected;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '退出多选',
                  onPressed: () {
                    setState(() {
                      _isInSelectionMode = false;
                      _selectedImageIDs.clear();
                      _isAllSelected = false;
                    });
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: '多选模式',
                  onPressed: () {
                    setState(() {
                      _isInSelectionMode = true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        // 图片列表
        Expanded(
          child: ListView.builder(
            itemCount: _images.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _images.length) {
                // 加载更多指示器
                Future.microtask(() {
                  if (_hasMore && _isLoading) {
                    _fetchMoreImages();
                  }
                });
                //_fetchMoreImages();
                return _buildLoadMoreIndicator();
              }

              final image = _images[index];
              final isSelected = _selectedImageId == image.imageID;
              final isProcessing = _processingImageIDs.contains(image.imageID);
              final isMultiSelected = _selectedImageIDs.contains(image.imageID);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: isSelected ? Colors.blue[50] : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    if (_isInSelectionMode) {
                      setState(() {
                        if (_selectedImageIDs.contains(image.imageID)) {
                          _selectedImageIDs.remove(image.imageID);
                        } else {
                          _selectedImageIDs.add(image.imageID);
                        }
                        _isAllSelected =
                            _selectedImageIDs.length == _images.length;
                      });
                    } else {
                      setState(() {
                        _selectedImageId = image.imageID;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // 多选模式下的复选框
                        if (_isInSelectionMode)
                          Checkbox(
                            value: isMultiSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedImageIDs.add(image.imageID);
                                } else {
                                  _selectedImageIDs.remove(image.imageID);
                                }
                                _isAllSelected =
                                    _selectedImageIDs.length == _images.length;
                              });
                            },
                          ),
                        // 图片缩略图
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isProcessing
                              ? const Center(child: CircularProgressIndicator())
                              : Image.network(
                                  '${UserSession().baseUrl}/${image.path}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.error),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(width: 12),
                        // 图片ID和状态
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID: ${image.imageID}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildImageStatusBadge(image.state),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 底部操作栏
        if (_isInSelectionMode && _selectedImageIDs.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('批量处理 (${_selectedImageIDs.length})'),
                  onPressed: _batchProcessImages,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 构建图片详情
  Widget _buildImageDetail() {
    final selectedImage = _images.firstWhere(
      (img) => img.imageID == _selectedImageId,
      orElse: () => _images.first,
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 图片详情内容 - 改为左右布局
          Expanded(
            flex: 3, // 右侧占3份宽度
            child: ImageDetail(
              key: ValueKey<int>(selectedImage.imageID), // 添加Key确保组件重建
              image: selectedImage,
              onImageUpdated: _handleImageUpdated,
              onImageDeleted: _handleImageDeleted,
              onImageOaUpdated: _handleImageQaUpadted,
            ),
          ),
        ],
      ),
    );
  }

  void _handleImageQaUpadted(ImageModel currentImage) {
    _executeAITask(currentImage);
    
  }

  // 加载更多图片
  Future<void> _fetchMoreImages() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _currentPage++;
    });

    await _fetchWorkDetails();
  }

  // 修改后的打回方法
  Future<void> _handleReturnWork(String returnReason, String remark) async {
    await WorkState.submitWork(
      context,
      _work!,
      5,
      returnReason: returnReason,
      remark: remark,
    );
    Navigator.pop(context); // 关闭弹窗
  }

  // 打回任务弹窗
  void _showReturnWorkDialog() {
    // 每次打开弹窗时清空输入内容
    _returnReasonController.clear();
    _remarkController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('打回任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '打回原因 (必填):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _returnReasonController,
                  decoration: const InputDecoration(
                    hintText: '请输入打回原因',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  '备注:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    hintText: '可输入额外说明',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = _returnReasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('打回原因不能为空')));
                  return;
                }

                _handleReturnWork(reason, _remarkController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认打回'),
            ),
          ],
        );
      },
    );
  }

  // 处理通过任务的方法
  Future<void> _handlePassWork(String passReason, String remark) async {
    Navigator.pop(context); // 关闭弹窗
    await WorkState.submitWork(
      context,
      _work!,
      6,
      returnReason: passReason,
      remark: remark,
    );
  }

  // 通过任务弹窗
  void _showPassWorkDialog() {
    // 每次打开弹窗时清空输入内容
    _passRemarkController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('通过任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  '备注:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _passRemarkController,
                  decoration: const InputDecoration(
                    hintText: '可输入额外说明（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                _handlePassWork(
                  _passReasonController.text.trim(),
                  _passRemarkController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认通过'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeAITask(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
    }
    try {
      final qa = await AiService.getQA(image);
      if (qa == null) throw Exception('AI服务返回空数据');

      final updatedImage = await _updateImageQA(
        image: image,
        questionText: qa.question,
        answers: qa.options,
        rightAnswerIndex: qa.correctAnswer,
        explanation: qa.explanation,
        textCOT: qa.textCOT,
      );

      setState(() {
        final index = _images.indexWhere(
          (img) => img.imageID == updatedImage!.imageID,
        );
        if (index != -1) {
          _images[index] = updatedImage!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片${updatedImage?.imageID}AI处理完成')),
        );
      }
    } catch (e, stackTrace) {
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

  Widget _buildImageStatusBadge(int state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ImageState.getStateColor(state).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
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

  Future<void> _batchProcessImages() async {
    if (_selectedImageIDs.isEmpty) return;

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

    final imagesToProcess = List<int>.from(_selectedImageIDs);
    final totalCount = imagesToProcess.length;

    setState(() {
      _processingImageIDs.addAll(imagesToProcess);
    });

    int processedCount = 0;
    final queue = Queue<Future>();
    const maxConcurrency = 5;

    for (final imageID in imagesToProcess) {
      while (queue.length >= maxConcurrency) {
        await Future.any(queue);
      }

      final image = _images.firstWhere((img) => img.imageID == imageID);
      final task = _executeAITask(image);

      queue.add(task);
      task
          .then((_) {
            processedCount++;
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
  }

}
