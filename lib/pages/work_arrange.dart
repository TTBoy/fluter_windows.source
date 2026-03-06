import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/MyWidget/UserDetailWidget.dart';
import 'package:qa_imageprocess/model/user.dart';
import 'dart:convert';

import 'package:qa_imageprocess/user_session.dart';


//安排任务界面
class WorkArrange extends StatefulWidget {
  const WorkArrange({super.key});

  @override
  State<WorkArrange> createState() => _WorkArrangeState();
}

class _WorkArrangeState extends State<WorkArrange> {
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = false;
  String _errorMessage = '';

  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;
  String? _selectedCollectorTypeName;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;
  String? _selectedQuestionDirectionName;
  // 难度和数量状态
  int? _selectedDifficulty;
  final TextEditingController _countController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchCategories(); // 初始化时获取类目
    _countController.text = '10'; // 默认数量
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${UserSession().baseUrl}/api/user/all'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _users = (data['data'] as List)
              .map((userJson) => User.fromJson(userJson))
              .toList();
        });
      } else {
        setState(() {
          _errorMessage = '获取用户列表失败: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络请求异常: $e';
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
      appBar: AppBar(title: const Text('任务分配')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : _buildMainLayout(),
    );
  }

  Widget _buildMainLayout() {
    return Row(
      children: [
        // 左侧用户列表
        Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[300]!)),
          ),
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                selected: _selectedUser?.userID == user.userID,
                onTap: () {
                  setState(() {
                    _selectedUser = user;
                  });
                },
              );
            },
          ),
        ),

        // 右侧详情区域
        Expanded(
          child: _selectedUser == null
              ? const Center(child: Text('请选择用户查看详情'))
              : UserDetailWidget(
                  user: _selectedUser!,
                  categories: _categories,
                  collectorTypes: _collectorTypes,
                  questionDirections: _questionDirections,
                  selectedCategoryId: _selectedCategoryId,
                  selectedCollectorTypeId: _selectedCollectorTypeId,
                  selectedQuestionDirectionId: _selectedQuestionDirectionId,
                  selectedDifficulty: _selectedDifficulty,
                  countController: _countController,
                  onCategorySelected: (id, name) {
                    setState(() {
                      _selectedCategoryId = id;
                      _selectedCategoryName = name;
                      _selectedCollectorTypeId = null;
                      _selectedCollectorTypeName = null;
                      _selectedQuestionDirectionId = null;
                      _selectedQuestionDirectionName = null;
                    });
                    if (id != null) {
                      _fetchCollectorTypes(id);
                    } else {
                      setState(() {
                        _collectorTypes = [];
                        _questionDirections = [];
                      });
                    }
                  },
                  onCollectorTypeSelected: (id, name) {
                    setState(() {
                      _selectedCollectorTypeId = id;
                      _selectedCollectorTypeName = name;
                      _selectedQuestionDirectionId = null;
                      _selectedQuestionDirectionName = null;
                    });
                    if (id != null) {
                      _fetchQuestionDirections(id);
                    } else {
                      setState(() {
                        _questionDirections = [];
                      });
                    }
                  },
                  onQuestionDirectionSelected: (id, name) {
                    setState(() {
                      _selectedQuestionDirectionId = id;
                      _selectedQuestionDirectionName = name;
                    });
                  },
                  onDifficultySelected: (difficulty) {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                  },
                  onAssignTask: _assignTask,
                ),
        ),
      ],
    );
  }

  // 分配任务方法
  Future<void> _assignTask() async {
    if (_selectedUser == null) return;

    // 验证所有选项都已选择
    if (_selectedCategoryId == null ||
        _selectedCollectorTypeId == null ||
        _selectedQuestionDirectionId == null ||
        _selectedDifficulty == null) {
      print('选择的难度：$_selectedDifficulty');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择所有必填参数（包括难度）')));
      return;
    }

    // 验证任务数量
    final count = int.tryParse(_countController.text);
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的任务数量（大于0）')));
      return;
    }

    // 准备API请求
    final url = Uri.parse('${UserSession().baseUrl}/api/works/assign');
    final headers = {
      'Authorization': 'Bearer ${UserSession().token}',
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      "workerID": _selectedUser!.userID,
      "category": _selectedCategoryName, // 注意API要求传递名称而不是ID
      "collector_type": _selectedCollectorTypeName,
      "question_direction": _selectedQuestionDirectionName,
      "targetCount": count,
      "difficulty": _selectedDifficulty,
    });

    print('请求参数：$body');

    try {
      final response = await http.post(url, headers: headers, body: body);

      print(response.body);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['code'] == 200) {
          // 成功处理
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('任务分配成功！任务ID: ${result['data']['workID']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          // 重置表单（可选）
          _resetForm();
        } else {
          // 服务器返回错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('分配失败: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // HTTP状态码错误
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请求失败: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 网络异常
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 重置表单
  void _resetForm() {
    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _selectedCollectorTypeId = null;
      _selectedCollectorTypeName = null;
      _selectedQuestionDirectionId = null;
      _selectedQuestionDirectionName = null;
      _selectedDifficulty = null;
      _countController.text = '10';
    });
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
