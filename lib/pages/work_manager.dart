import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qa_imageprocess/model/user.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/user_session.dart';

//Work管理界面
class WorkManager extends StatefulWidget {
  const WorkManager({super.key});

  @override
  State<WorkManager> createState() => _WorkManagerState();
}

class _WorkManagerState extends State<WorkManager> {
  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  // 用户相关状态 - 与其他选项隔离
  List<User> _users = [];
  String? _selectedUserId;
  User? _selectedUser;

  // 任务列表相关状态
  List<WorkModel> _works = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalItems = 0;
  int _totalPages = 1;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // 初始化时获取类目
    _fetchAllUsers();

    // 添加滚动监听器
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听器
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreWorks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTitleSelector(),
          Expanded(child: _buildWorkList()),
        ],
      ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800;

          final children = [
            _buildCategoryDropdown(),
            _buildCollectorTypeDropdown(),
            _buildQuestionDirectionDropdown(),
            _buildUserDropdown(),
            _buildSearchButton(),
            if (UserSession().role == 1) _buildWorkButton(),
          ];

          if (isWideScreen) {
            return Row(
              children: children
                  .map(
                    (child) => Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: child,
                      ),
                    ),
                  )
                  .toList(),
            );
          } else {
            return Wrap(spacing: 16, runSpacing: 16, children: children);
          }
        },
      ),
    );
  }

  bool _isAdmin() {
    return UserSession().role == 1;
  }

  Widget _buildCategoryDropdown() {
    return Row(
      children: [
        _buildLevelDropdown(
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
        ),
        if (_isAdmin())
          IconButton(
            onPressed: () => {_showAddCategoryDialog()},
            icon: Icon(Icons.add),
          ),
      ],
    );
  }

  Widget _buildCollectorTypeDropdown() {
    return Row(
      children: [
        _buildLevelDropdown(
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
        ),
        if (_isAdmin())
          IconButton(
            onPressed: () => {_showAddCollectorTypeDialog()},
            icon: Icon(Icons.add),
          ),
      ],
    );
  }

  Widget _buildQuestionDirectionDropdown() {
    return Row(
      children: [
        _buildLevelDropdown(
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
        ),
        if (_isAdmin())
          IconButton(
            onPressed: () => {_showAddQuestionDirectionDialog()},
            icon: Icon(Icons.add),
          ),
      ],
    );
  }

  // 添加类目弹窗
  void _showAddCategoryDialog() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新类目'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '类目名称'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入类目名称';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _addCategory(_nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 添加采集类型弹窗
  void _showAddCollectorTypeDialog() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新采集类型'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '采集类型名称'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入采集类型名称';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _addCollectorType(_nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 添加问题方向弹窗
  void _showAddQuestionDirectionDialog() {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _simpleTargetController = TextEditingController();
    final _difficultTargetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新问题方向'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '问题方向名称'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入问题方向名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _simpleTargetController,
                decoration: const InputDecoration(labelText: '简单数量'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入简单数量';
                  }
                  if (int.tryParse(value) == null) {
                    return '请输入有效数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _difficultTargetController,
                decoration: const InputDecoration(labelText: '中等数量'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入中等数量';
                  }
                  if (int.tryParse(value) == null) {
                    return '请输入有效数字';
                  }
                  return null;
                },
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
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _addQuestionDirection(
                  _nameController.text,
                  int.parse(_simpleTargetController.text),
                  int.parse(_difficultTargetController.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 添加类目
  Future<void> _addCategory(String name) async {
    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/category/'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'categoryName': name}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('类目添加成功')));
        _fetchCategories(); // 刷新类目列表
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加出错: $e')));
    }
  }

  // 添加采集类型
  Future<void> _addCollectorType(String name) async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择类目')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/category/collector-types'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'categoryID': int.parse(_selectedCategoryId!),
          'collectorTypeName': name,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('采集类型添加成功')));
        _fetchCollectorTypes(_selectedCategoryId); // 刷新采集类型列表
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加出错: $e')));
    }
  }

  // 添加问题方向
  Future<void> _addQuestionDirection(
    String name,
    int simpleTarget,
    int difficultTarget,
  ) async {
    if (_selectedCollectorTypeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择采集类型')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/category/question-directions'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'collectorTypeID': int.parse(_selectedCollectorTypeId!),
          'questionDirectionName': name,
          'simpletarget': simpleTarget,
          'difficulttarget': difficultTarget,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('问题方向添加成功')));
        _fetchQuestionDirections(_selectedCollectorTypeId); // 刷新问题方向列表
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加出错: $e')));
    }
  }

  // 专门为用户下拉框创建的组件 - 添加空选项
  Widget _buildUserDropdown() {
    // 修复：直接构建菜单项列表
    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他用户选项
      ..._users.map((user) {
        return DropdownMenuItem<String?>(
          value: user.userID.toString(),
          child: Text(user.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    ];

    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        value: _selectedUserId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '分配用户',
          border: OutlineInputBorder(),
        ),
        items: items,
        onChanged: (newValue) {
          setState(() {
            _selectedUserId = newValue;
            if (newValue != null) {
              _selectedUser = _users.firstWhere(
                (user) => user.userID.toString() == newValue,
                orElse: () => User(
                  userID: -1,
                  name: '未知用户',
                  email: '',
                  role: 0,
                  state: 0,
                ),
              );
            } else {
              _selectedUser = null; // 清空选择
            }
          });
        },
      ),
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
    // 提取中文括号内的内容
    String extractChineseBracketContent(String text) {
      // 使用正则表达式匹配中文括号及其内容
      RegExp exp = RegExp(r'（([^）]+)）');
      Match? match = exp.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!;
      }
      return text; // 如果没有匹配到中文括号，返回原文本
    }

    final items = [
      // 添加空选项
      DropdownMenuItem<String?>(
        value: null,
        child: Text('未选择', style: TextStyle(color: Colors.grey)),
      ),
      // 添加其他选项
      ...options.map((id) {
        String displayText = displayValues[id] ?? '未知';
        // 提取中文括号内的内容
        displayText = extractChineseBracketContent(displayText);

        return DropdownMenuItem<String?>(
          value: id,
          child: Text(displayText, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    ];

    return SizedBox(
      width: 136,
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

  // 查询按钮
  Widget _buildSearchButton() {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _searchWorks,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text('查询任务', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildWorkButton() {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () => {Navigator.pushNamed(context, '/workArrange')},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('分配任务'),
      ),
    );
  }

  // 搜索任务（重置分页）
  Future<void> _searchWorks() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _works.clear();
    });
    await _fetchWorks(append: false);
  }

  // 加载更多任务
  Future<void> _loadMoreWorks() async {
    if (_hasMore && !_isLoadingMore) {
      setState(() {
        _currentPage++;
      });
      await _fetchWorks(append: true);
    }
  }

  // 查询任务列表
  Future<void> _fetchWorks({bool append = false}) async {
    if (append) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      // 构建查询参数
      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString(),
      };

      // 添加可选参数
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

      if (_selectedUserId != null) {
        queryParams['userID'] = _selectedUserId!;
      }

      // 构建URL
      final uri = Uri.parse(
        '${UserSession().baseUrl}/api/works/admin/user-works',
      ).replace(queryParameters: queryParams);

      // 发送请求
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${UserSession().token ?? ''}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final worksData = data['data']['works'] as List? ?? [];
        final pagination =
            data['data']['pagination'] as Map<String, dynamic>? ?? {};

        final newWorks = worksData.map<WorkModel>((work) {
          return WorkModel.fromJson(work as Map<String, dynamic>);
        }).toList();

        setState(() {
          if (append) {
            _works.addAll(newWorks);
          } else {
            _works = newWorks;
          }

          // 安全处理可能为 null 的值
          _currentPage = (pagination['currentPage'] as int?) ?? _currentPage;
          _pageSize = (pagination['pageSize'] as int?) ?? _pageSize;
          _totalItems = (pagination['totalItems'] as int?) ?? _totalItems;
          _totalPages = (pagination['totalPages'] as int?) ?? _totalPages;

          // 更新是否还有更多数据
          _hasMore = _currentPage < _totalPages;
        });
      } else {
        throw Exception('Failed to load works: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching works: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载任务失败: $e')));
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // 任务列表
  Widget _buildWorkList() {
    if (_works.isEmpty && !_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '暂无任务数据',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                '请调整筛选条件后重新查询',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _searchWorks,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: _works.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _works.length) {
            // 加载更多指示器
            return Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.center,
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            );
          }

          final work = _works[index];
          return _buildWorkItem(work);
        },
      ),
    );
  }

  // 单个任务项
  Widget _buildWorkItem(WorkModel work) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // final isWideScreen = constraints.maxWidth > 600;

            // if (isWideScreen) {
            return _buildWideScreenLayout(work);
            // } else {
            //   return _buildNarrowScreenLayout(work);
            // }
          },
        ),
      ),
    );
  }

  // 宽屏布局
  Widget _buildWideScreenLayout(WorkModel work) {
    return Row(
      children: [
        // 任务基本信息
        Expanded(flex: 2, child: _buildTaskInfo(work)),
        const SizedBox(width: 16),

        // 进度信息
        Expanded(flex: 1, child: _buildProgressInfo(work)),
        const SizedBox(width: 16),

        // 状态和操作
        SizedBox(width: 120, child: _buildStatusAndActions(work)),
      ],
    );
  }

  // 任务基本信息
  Widget _buildTaskInfo(WorkModel work) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '任务 #${work.workID}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            _buildDifficultyBadge(work.difficulty),
          ],
        ),
        const SizedBox(height: 8),
        Text('类目: ${work.category}', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          '类型: ${work.collectorType}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          '方向: ${work.questionDirection}',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  // 进度信息
  Widget _buildProgressInfo(WorkModel work) {
    final progress = work.targetCount > 0
        ? work.currentCount / work.targetCount
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '管理员: ${work.admin.name}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.work, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '工作人员: ${work.worker.name}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.time_to_leave, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '创建时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(work.created_at))}',
            ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? Colors.green : Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${work.currentCount}/${work.targetCount}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // 难度徽章
  Widget _buildDifficultyBadge(int difficulty) {
    final colors = {0: Colors.green, 1: Colors.orange, 2: Colors.red};

    final labels = {0: '简单', 1: '中等', 2: '困难'};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[difficulty] ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors[difficulty] ?? Colors.grey, width: 1),
      ),
      child: Text(
        labels[difficulty] ?? '未知',
        style: TextStyle(
          color: colors[difficulty] ?? Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 状态徽章
  Widget _buildStatusBadge(WorkModel work) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WorkModel.getWorkStateColor(work.state).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkModel.getWorkStateColor(work.state)),
      ),
      child: Text(
        WorkModel.getWorkState(work.state),
        style: TextStyle(
          color: WorkModel.getWorkStateColor(work.state),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // 状态和操作（宽屏用）
  Widget _buildStatusAndActions(WorkModel work) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStatusBadge(work),
        const SizedBox(height: 5),
        _buildActionButtons(work),
        const SizedBox(height: 5),
        if (work.state == 3)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => {_getInspectWork(work)},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.orangeAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('质检'),
            ),
          ),
      ],
    );
  }

  //拉取质检任务
  Future<void> _getInspectWork(WorkModel work) async {
    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/works/assign-inspection'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'workID': work.workID}),
      );

      print(response.body);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] == null) {
          throw FormatException('API响应缺少数据字段');
        }
        final updatedWork = WorkModel.fromJson(jsonData['data']);
        setState(() {
          final index = _works.indexWhere(
            (work) => work.workID == updatedWork.workID,
          );
          if (index != -1) {
            _works[index] = updatedWork;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拉取质检任务成功')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拉取质检任务失败${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('拉取质检任务出错$e')));
    }
  }

  // 操作按钮
  Widget _buildActionButtons(WorkModel work) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _viewWorkDetails(work),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade50,
          foregroundColor: Colors.blue,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.visibility, size: 16),
        label: const Text('查看'),
      ),
    );
  }

  void _viewWorkDetails(WorkModel work) {
    Navigator.pushNamed(
      context,
      '/workDetail',
      arguments: {'workID': work.workID},
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

  // 获取所有用户信息的方法
  Future<void> _fetchAllUsers() async {
    try {
      final allUsers = await _fetchData('/api/user/all');
      setState(() {
        _users = (allUsers).map<User>((item) {
          return User.fromJson(item as Map<String, dynamic>);
        }).toList();
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() {
        _users = [];
      });
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
