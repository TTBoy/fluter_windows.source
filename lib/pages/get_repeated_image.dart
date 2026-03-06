import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/MyWidget/image_detail.dart';
import 'package:qa_imageprocess/model/image_model.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/image_state.dart';
import 'package:qa_imageprocess/model/question_model.dart';
import 'package:qa_imageprocess/user_session.dart';


//调用接口，返回完全一模一样的图片，MD5值相同。
class DuplicateGroupModel {
  final String fileName;
  final int count;
  final List<ImageModel> images;

  DuplicateGroupModel({
    required this.fileName,
    required this.count,
    required this.images,
  });

  factory DuplicateGroupModel.fromJson(Map<String, dynamic> json) {
    return DuplicateGroupModel(
      fileName: json['fileName'] as String,
      count: json['count'] as int,
      images: (json['images'] as List)
          .map((imageJson) => ImageModel.fromJson(imageJson))
          .toList(),
    );
  }
}

class PaginationModel {
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  PaginationModel({
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      currentPage: json['currentPage'] as int,
      pageSize: json['pageSize'] as int,
      totalItems: json['totalItems'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}

class GetRepeatedImage extends StatefulWidget {
  const GetRepeatedImage({super.key});

  @override
  State<GetRepeatedImage> createState() => _GetRepeatedImageState();
}

class _GetRepeatedImageState extends State<GetRepeatedImage> {
  List<DuplicateGroupModel> duplicateGroups = [];
  PaginationModel? pagination;
  int currentPage = 1;
  int pageSize = 10;
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // bool isRepeatedImageModel=true;
  // bool isErrorImageModel=false;


  @override
  void initState() {
    super.initState();
    _fetchDuplicateGroups();
  }


  //获取重复图片组
  Future<void> _fetchDuplicateGroups() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${UserSession().baseUrl}/api/image/duplicates?page=$currentPage&pageSize=$pageSize',
        ),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      // print(response.body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final groups = (responseData['data']['duplicateGroups'] as List)
            .map((group) => DuplicateGroupModel.fromJson(group))
            .toList();

        final paginationData = PaginationModel.fromJson(
          responseData['data']['pagination'],
        );

        setState(() {
          duplicateGroups = groups;
          pagination = paginationData;
          currentPage = paginationData.currentPage;
        });
      } else {
        throw Exception('请求失败: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载失败: ${e.toString()}')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _changePage(int newPage) {
    if (newPage >= 1 && newPage <= (pagination?.totalPages ?? 1)) {
      setState(() => currentPage = newPage);
      _fetchDuplicateGroups();
      // 滚动到顶部
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _changePageSize(int? newSize) {
    if (newSize != null && newSize != pageSize) {
      setState(() {
        pageSize = newSize;
        currentPage = 1;
      });
      _fetchDuplicateGroups();
    }
  }

  // 构建单列布局（小屏幕）
  Widget _buildListLayout(DuplicateGroupModel group) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: group.images.length,
      itemBuilder: (context, index) => _buildGridItem(group.images[index]),
    );
  }

  // 构建网格布局（大屏幕）
  Widget _buildGridLayout(DuplicateGroupModel group) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: group.images.length,
      itemBuilder: (context, index) => _buildGridItem(group.images[index]),
    );
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
            onDeprecateImage: _handelDeprecateImage,
          ),
        );
      },
    );
  }

  void _handelDeprecateImage(int imageID) {
    setState(() {
      // 遍历所有重复分组
      for (var i = 0; i < duplicateGroups.length; i++) {
        final group = duplicateGroups[i];

        // 在当前分组中查找需要删除的图片
        final index = group.images.indexWhere((img) => img.imageID == imageID);
        if (index != -1) {
          // 从分组中移除图片
          group.images.removeAt(index);

          // 更新分组的计数
          final updatedGroup = DuplicateGroupModel(
            fileName: group.fileName,
            count: group.count - 1,
            images: group.images,
          );

          // 替换原分组
          duplicateGroups[i] = updatedGroup;

          // 如果分组中图片数量少于2，移除整个分组（不再构成重复）
          if (updatedGroup.images.length < 2) {
            duplicateGroups.removeAt(i);
          }
          Navigator.pop(context);

          break;
        }
      }
    });
  }

  // 处理图片更新回调
  void _handleImageUpdated(ImageModel updatedImage) {
    setState(() {
      // 遍历所有重复分组
      for (var group in duplicateGroups) {
        // 在当前分组中查找需要更新的图片
        final index = group.images.indexWhere(
          (img) => img.imageID == updatedImage.imageID,
        );
        if (index != -1) {
          // 更新图片信息
          group.images[index] = updatedImage;
          break;
        }
      }
    });
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

  Widget _buildGroupDetail(DuplicateGroupModel group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${group.count}个重复'),
                backgroundColor: Colors.blue[100],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '分组内图片数量: ${group.images.length}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // 响应式布局 - 小屏幕使用列表，大屏幕使用网格
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return _buildListLayout(group);
              } else {
                return _buildGridLayout(group);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (pagination == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('每页显示:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: pageSize,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: _changePageSize,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 1
                    ? () => _changePage(currentPage - 1)
                    : null,
              ),
              Text('${pagination!.currentPage}/${pagination!.totalPages}'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < pagination!.totalPages
                    ? () => _changePage(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重复图片管理'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => {_fetchDuplicateGroups()},
            icon: Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          SizedBox(width: 15),
          SizedBox(
            width: 120,
            height: 36,
            child: ElevatedButton(
              onPressed: () => {
                Navigator.pushNamed(context, '/getSimilarImage'),
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('查找相似'),
            ),
          ),
          SizedBox(width: 15),
          SizedBox(
            width: 120,
            height: 36,
            child: ElevatedButton(
              onPressed: () => {
                Navigator.pushNamed(context, '/findError'),
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('错误查询'),
            ),
          ),
          SizedBox(width: 30),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : duplicateGroups.isEmpty
          ? const Center(
              child: Text('没有找到重复图片', style: TextStyle(fontSize: 16)),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      ...duplicateGroups.map(
                        (group) => Card(
                          margin: const EdgeInsets.all(16),
                          child: _buildGroupDetail(group),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                _buildPagination(),
              ],
            ),
    );
  }
}
