import 'dart:collection';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/answer_model.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/pages/dialog/category.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/user_session.dart';

class Finderror extends StatefulWidget {
  const Finderror({super.key});

  @override
  State<Finderror> createState() => _FinderrorState();
}

///查询错误的图片项
/// [_isErrorUrl] ，过滤图片链接异常
///根据查询条件循环获取所有满足查询条件的图片到[_images]列表，图片数量很多，可以调整分页参数[_pageSize]，获取所有图片的过程并不需要显示图片列表
///获取到所有图片后会调用[_screenImages]方法来筛选图片，筛选后的图片放到一个新的列表[_screenedImage]中
///只有在[_images]为空的时候才从数据库查询图片，否则只调用[_screenImages]方法过滤图片
/////////////////////////////////////////////////////////////////////////////////////
class _FinderrorState extends State<Finderror> {
  //分页查询参数
  int _currentPage = 1;
  int _totalPages = 0;
  int _pageSize = 60;
  bool _isLoading = false;
  bool _hasMore = true;
  int _columnCount = 4; // 默认4列

  //选择的类目，采集方向和问题方向
  String _catergory = '';
  String _collectorType = '';
  String _questionDirection = '';

  //所有图片
  List<ImageModel> _images = [];

  //筛选后的图片
  List<ImageModel> _screenedImage = [];
  //是否在筛选
  bool _isScreening = false;

  String _errorMessage = '';
  // 添加滚动控制器
  final ScrollController _scrollController = ScrollController();

  //正在处理的图片ID
  Set<int> _processingImageIDs = {}; // 记录正在处理AI的图片ID

  Set<int> _selectedImageIDs = {}; // 存储选中的图片ID
  bool _isInSelectionMode = false; // 是否处于多选模式

  //图片筛选模式
  bool _isErrorUrl = false; //图片链接异常
  bool _isNullQuestion = false; //无问题
  bool _isNullOptions = false; //无选项
  bool _isNullAnswer = false; //无答案
  bool _isNullCOT = false; //无COT
  bool _isNullExplanation = false; //无解析
  bool _isResolution = false; //分辨率筛选
  int _width = 720; //最小宽度
  int _height = 720; //最小高度

  //时间筛选
  DateTime? _startDate; //开始日期
  DateTime? _endDate; //结束日期

  //分辨率输入控制器
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  //是否正在获取全部图片
  bool _isFetchingAll = false;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: _width.toString());
    _heightController = TextEditingController(text: _height.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('错误图片查询'),
        actions: [
          // 主要筛选条件（保留重要选项）
          _buildCheckbox('链接异常', _isErrorUrl, (value) {
            setState(() => _isErrorUrl = value!);
          }),
          _buildCheckbox('无问题', _isNullQuestion, (value) {
            setState(() => _isNullQuestion = value!);
          }),
          _buildCheckbox('无答案', _isNullAnswer, (value) {
            setState(() => _isNullAnswer = value!);
          }),
          _buildCheckbox('无选项', _isNullOptions, (value) {
            setState(() => _isNullOptions = value!);
          }),
          _buildCheckbox('无COT', _isNullCOT, (value) {
            setState(() => _isNullCOT = value!);
          }),
          _buildCheckbox('无解析', _isNullExplanation, (value) {
            setState(() => _isNullExplanation = value!);
          }),
          _buildCheckbox('分辨率', _isResolution, (value) {
            setState(() => _isResolution = value!);
          }),
          if (_isResolution) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 55,
              child: TextField(
                controller: _widthController,
                decoration: InputDecoration(hintText: '宽'),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => _width = int.tryParse(v) ?? 720),
              ),
            ),
            SizedBox(width: 5),
            Text('×'),
            SizedBox(width: 5),
            SizedBox(
              width: 55,
              child: TextField(
                controller: _heightController,
                decoration: InputDecoration(hintText: '高'),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => _height = int.tryParse(v) ?? 720),
              ),
            ),
          ],

          const SizedBox(width: 8),

          // 日期选择器（简化版）
          _buildCompactDatePicker(
            '开始',
            _startDate,
            (date) => setState(() => _startDate = date),
          ),
          const SizedBox(width: 4),
          _buildCompactDatePicker(
            '结束',
            _endDate,
            (date) => setState(() => _endDate = date),
          ),
          const SizedBox(width: 8),
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
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => {_batchProcessImages(0)},
              tooltip: '批量QA',
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.question_answer),
              onPressed: () => {_batchProcessImages(1)},
              tooltip: '批量答案',
              color: Colors.orangeAccent,
            ),
            IconButton(
              icon: const Icon(Icons.tips_and_updates),
              onPressed: () => {_batchProcessImages(2)},
              tooltip: '批量解析',
              color: Colors.green,
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _deselectAllImages,
              tooltip: '退出多选',
              color: Colors.red,
            ),
          ] else if (_images.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _isInSelectionMode = true),
              tooltip: '多选模式',
            ),
          ],
          IconButton(
            onPressed: () => {_showValueDialog()},
            icon: Icon(Icons.filter_list),
            tooltip: '额外参数',
          ),
          IconButton(
            onPressed: () => {_handleClear()},
            icon: Icon(Icons.clear),
            tooltip: '清除',
          ),
          SizedBox(width: 8),
          // 查询按钮
          SizedBox(
            width: 90,
            height: 35,
            child: ElevatedButton(
              onPressed: () => {_handleSearch()},
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
          SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // _buildTitleSelector(),
          // 添加网格视图展示图片
          Row(
            children: [
              Text('$_catergory         $_collectorType           $_questionDirection')
            ],
          ),
          if (_images.isEmpty && _isLoading)
            Center(child: CircularProgressIndicator()),
          Expanded(
            child: _images.isEmpty && !_isLoading
                ? Center(
                    child: Text(_errorMessage.isEmpty ? '暂无数据' : _errorMessage),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      // 防止在加载过程中重复触发
                      // 修改滚动加载逻辑
                      if (!_isLoading &&
                          _hasMore &&
                          !_isScreening && // 不在筛选时才加载下一页
                          !_isFetchingAll && // 不是正在获取所有图片时
                          scrollNotification.metrics.pixels >=
                              scrollNotification.metrics.maxScrollExtent -
                                  200) {
                        _loadNextPage();
                      }
                      return true;
                    },
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columnCount,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _screenedImage.length,
                      itemBuilder: (context, index) {
                        // 计算当前列表中的总项数（不包括加载指示器）
                        final imageCount = _screenedImage.length;

                        // 检查是否是加载指示器项目
                        if (index >= imageCount) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // 获取对应的图片
                        final image = _screenedImage[index];

                        return _buildGridItem(image);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _toggleColumnCount,
        tooltip: '切换列数 ($_columnCount)',
        child: Text('$_columnCount列'),
      ),
    );
  }

  void _showValueDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          child: Category(
            onCategorySelected: (category) {
              setState(() {
                _catergory = category;
              });
            },
            onCollevtypeSelected: (collectorType) {
              setState(() {
                _collectorType = collectorType;
              });
            },
            onQuestionDirectionSelected: (questionDirection) {
              setState(() {
                _questionDirection = questionDirection;
              });
            },
          ),
        );
      },
    );
  }

  //全选所有图片
  void _selectAllImages() {
    setState(() {
      _selectedImageIDs = Set<int>.from(_screenedImage.map((img) => img.imageID));
      _isInSelectionMode = true;
    });
  }

  //打开额外参数选择弹窗（选择类目采集类型，问题方向等查询参数）
  void openFliterDialog() {}

  //筛选图片
  Future<List<ImageModel>> _screenImages(List<ImageModel> images) async {
    List<ImageModel> screenedImages = [];

    for (var image in images) {
      bool include = false;

      if (_isErrorUrl) {
        // 添加图片URL有效性的检查逻辑
      }

      if (_isNullQuestion) {
        if (image.questions!.isEmpty) {
          include = true;
        }
      }

      if (_isNullOptions) {
        if (image.questions!.isEmpty ||
            image.questions!.first.answers.isEmpty) {
          include = true;
        }
      }

      if (_isNullAnswer) {
        if (image.questions!.isEmpty ||
            image.questions!.first.rightAnswer == null) {
          include = true;
        }
      }

      if (_isNullExplanation) {
        if (image.questions!.isEmpty ||
            image.questions!.first.explanation == null) {
          include = true;
        }
      }

      if (_isNullCOT) {
        if (image.questions!.isEmpty ||
            image.questions!.first.textCOT == null) {
          include = true;
        }
      }

      if (_isResolution) {
        // 解析图片分辨率信息
      }

      if (include) {
        screenedImages.add(image);
      }
    }

    return screenedImages;
  }

  //图片批量处理
  Future<void> _batchProcessImages(int model) async {
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

      Future task;
      // 先声明 task 变量
      switch (model) {
        case 0:
          task = _executeAITask(image);
        case 1:
          task = _executeAIAnswerAnexplanation(image);
        case 2:
          task = _executeAIExplanationCOT(image);
        default:
          task = _executeAITask(image);
      }
      ;

      // 将任务添加到队列
      queue.add(task);
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

  //清除选中图片
  void _deselectAllImages() {
    setState(() {
      _selectedImageIDs.clear();
      _isInSelectionMode = false;
    });
  }

  // 精简日期选择器
  Widget _buildCompactDatePicker(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> onSelected,
  ) {
    return InkWell(
      onTap: () => _selectDate(context, date, onSelected),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(
              date != null ? '${date.month}/${date.day}' : label,
              style: TextStyle(fontSize: 12),
            ),
            Icon(Icons.calendar_today, size: 14),
          ],
        ),
      ),
    );
  }

  // 选择日期
  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    ValueChanged<DateTime?> onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != initialDate) {
      onDateSelected(picked);
    }
  }

  //选择框
  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
      ],
    );
  }

  // 加载下一页
  void _loadNextPage() {
    setState(() {
      _currentPage++;
      _isLoading = true;
    });
    _fetchImages();
  }

  // 悬浮按钮列数切换，4~7列
  void _toggleColumnCount() {
    setState(() {
      _columnCount = _columnCount >= 7 ? 4 : _columnCount + 1;
    });
  }

  //查询方法，在_images为空时，获取所有图片信息并根据条件对图片进行过滤。不为空时，只进行过滤。
  void _handleSearch() async {
    setState(() {
      _isLoading = true;

      // 如果需要重新加载或当前没有数据
      if (_images.isEmpty) {
        _currentPage = 1;
        _images.clear();
        _hasMore = true;
        _isFetchingAll = true; // 开始加载所有图片
      }
    });

    if (_isFetchingAll) {
      // 加载所有图片
      await _fetchAllImages();
    }

    // 无论是否加载新数据，都进行筛选
    setState(() {
      _isLoading = true;
      _isScreening = true;
    });

    // 执行筛选
    _screenedImage = await _screenImages(_images);

    setState(() {
      _isLoading = false;
      _isScreening = false;
    });
  }

  // 清除处理方法
  void _handleClear() {
    setState(() {
      _images.clear();
      _screenedImage.clear();
      _isFetchingAll = false;
      _isScreening = false;
      _hasMore = true;
      _currentPage = 1;
    });
  }

  //循环分页获取所有图片
  Future<void> _fetchAllImages() async {
    await _fetchImages();
    setState(() {
      _isLoading = true;
    });
    while (_currentPage <= _totalPages) {
      
      setState(() {
        _currentPage++;
      });
      // if (_currentPage == _totalPages) break;
      await _fetchImages();
    }

    setState(() {
      _isFetchingAll = false;
    });
  }

  //分页获取图片
  Future<void> _fetchImages() async {
    final Map<String, String> queryParams = {
      'page': _currentPage.toString(),
      'pageSize': _pageSize.toString(),
    };

      queryParams['category'] = _catergory;

      queryParams['collector_type'] = _collectorType;
      queryParams['question_direction']=_questionDirection;


    if (_startDate != null) {
      queryParams['startTime'] = _startDate!.millisecondsSinceEpoch.toString();
    }
    if (_endDate != null) {
      queryParams['endTime'] = _endDate!.millisecondsSinceEpoch.toString();
    }

    // 构建URL
    final uri = Uri.parse(
      '${UserSession().baseUrl}/api/image',
    ).replace(queryParameters: queryParams);

    try {
      // 发送请求
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
      );
      print(response.body);
      // print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pagination = data['data'];
        final imageData = pagination['data'] as List;

        print('获取$_currentPage');

        setState(() {
          _totalPages = pagination['totalPages'] as int;
          if (_currentPage == 1) {
            _images = imageData.map((img) => ImageModel.fromJson(img)).toList();
          } else {
            _images.addAll(imageData.map((img) => ImageModel.fromJson(img)));
          }

          print(_totalPages);

          _errorMessage = '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络错误图片查询失败${response.statusCode}')),
        );
        _isLoading = false;
      }
    } catch (e) {
      // ScaffoldMessenger.of(
      //   context,
      // ).showSnackBar(SnackBar(content: Text('图片查询失败$e')));
      _isLoading = false;
    }
  }

  //打开图片详情弹窗
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
            onImageUpdated: _handleImageUpdated, //处理图片更新回调
            onClose: () => Navigator.pop(context), //关闭图片详情弹窗
            onImageDeleted: _handleImageDeleted, //图片删除回调（删除数据库数据和图片文件）
            onImageOaUpdated: _handleImageQaUpadted, //更新问题答案解析等
            onExplanationUpdated: _handleExplanationUpdated, //单独更新解析和COT
            onAnswerUpdated: _handleAnswerUpdated, //更新答案
            onDeprecateImage: _handleImageDeleted, //删除数据库中的图片信息，并不删除图片文件
          ),
        );
      },
    );
  }

  //列表项
  Widget _buildGridItem(ImageModel image) {
    final firstQuestion = image.questions?.isNotEmpty == true
        ? image.questions?.first
        : null;
    final bool isProcessing = _processingImageIDs.contains(image.imageID);
    final bool isSelected = _selectedImageIDs.contains(image.imageID);

    return GestureDetector(
      onLongPress: () => {},
      onTap: () {
        // setState(() {
        //   _selectedImageId = image.imageID;
        // });
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
          //多选标识
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
          //处理中标识
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
    );
  }

  // 多选辅助方法
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

  // 处理图片更新回调
  void _handleImageUpdated(ImageModel updatedImage) {
    setState(() {
      // 找到并更新图片列表中的对应图片
      final index = _screenedImage.indexWhere(
        (img) => img.imageID == updatedImage.imageID,
      );
      if (index != -1) {
        _screenedImage[index] = updatedImage;
      }
    });
  }

  //处理图片删除
  void _handleImageDeleted(int imageID) {
    setState(() {
      final index = _screenedImage.indexWhere((img) => img.imageID == imageID);
      if (index != -1) {
        _screenedImage.removeAt(index); // 通过索引删除元素
      }
    });
    Navigator.pop(context);
  }

  ///更新图片信息（问题答案解析等）
  ///[image]，传入的图片对象
  ///[questionText]，要更新的问题文本
  ///[explanation]，可选，新的解析
  ///[textCOT]，可选，新的解题思路
  ///[answers]，String答案数组
  ///[rightAnswerIndex]，正确答案在答案数组中的位置索引
  //////////////////////////////////////////////
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

  void _handleImageQaUpadted(ImageModel updatedImage) {
    _executeAITask(updatedImage);
  }

  Future<void> _executeAITask(ImageModel image) async {
    if (mounted) {
      setState(() {
        _processingImageIDs.add(image.imageID);
      });
    }
    try {
      // 1. 调用AI服务
      final qa = await AiService.getQA(image);
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
        final index = _screenedImage.indexWhere(
          (img) => img.imageID == updatedImage!.imageID,
        );
        if (index != -1) {
          _screenedImage[index] = updatedImage!;
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

  void _handleExplanationUpdated(ImageModel updatedImage) {
    _executeAIExplanationCOT(updatedImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
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
          final index = _screenedImage.indexWhere(
            (img) => img.imageID == updatedImage!.imageID,
          );
          if (index != -1) {
            _screenedImage[index] = updatedImage!;
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

  void _handleAnswerUpdated(ImageModel updatedImage) {
    _executeAIAnswerAnexplanation(updatedImage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加载，可关闭弹窗')));
  }

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
          final index = _screenedImage.indexWhere(
            (img) => img.imageID == updatedImage!.imageID,
          );
          if (index != -1) {
            _screenedImage[index] = updatedImage!;
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
}
