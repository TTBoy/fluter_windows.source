import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/user_session.dart';

class Category extends StatefulWidget {
  final Function(String category) onCategorySelected;
  final Function(String collectorType) onCollevtypeSelected;
  final Function(String questionDirection) onQuestionDirectionSelected;

  const Category({
    super.key,
    required this.onCategorySelected,
    required this.onCollevtypeSelected,
    required this.onQuestionDirectionSelected,
  });

  @override
  State<Category> createState() => _CategoryState();
}

class _CategoryState extends State<Category> {
  // 类目相关状态
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;

  // 采集类型相关状态
  List<Map<String, dynamic>> _collectorTypes = [];
  String? _selectedCollectorTypeId;

  // 问题方向相关状态
  List<Map<String, dynamic>> _questionDirections = [];
  String? _selectedQuestionDirectionId;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      height: 500,
      child: Column(
        children: [
          // 顶部工具栏容器
          Container(
            height: 80,
            child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 水平居中排列
            children: [
              _buildCategoryDropdown(),
              SizedBox(width: 32),
              _buildCollectorTypeDropdown(),
              SizedBox(width: 32),
              _buildQuestionDirectionDropdown(),
            ],
          ),
          ),
          Expanded(child: SizedBox()),
          // 其他内容...
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      height: 400,
      child: Row(
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
                widget.onCategorySelected(
                  (_categories.firstWhere(
                    (c) => c['id'] == newValue,
                    orElse: () => {'name': ''},
                  ))['name'],
                );
                widget.onCollevtypeSelected('');
                widget.onQuestionDirectionSelected('');
              });
              _fetchCollectorTypes(newValue);
            },
          ),
        ],
      ),
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
              widget.onCollevtypeSelected(
                (_collectorTypes.firstWhere(
                  (c) => c['id'] == newValue,
                  orElse: () => {'name': ''},
                ))['name'],
              );
              widget.onQuestionDirectionSelected('');
            });
            _fetchQuestionDirections(newValue);
          },
          enabled: _selectedCategoryId != null,
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
              widget.onQuestionDirectionSelected(
                (_questionDirections.firstWhere(
                  (c) => c['id'] == newValue,
                  orElse: () => {'name': ''},
                ))['name'],
              );
            });
          },
          enabled: _selectedCollectorTypeId != null,
        ),
      ],
    );
  }

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
