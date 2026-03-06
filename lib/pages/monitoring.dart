import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/image_state.dart';
import 'dart:convert';
import 'package:qa_imageprocess/user_session.dart';

//统计采集图片的总数，每一个分类的数量，显示在一个树状列表里
class Monitoring extends StatefulWidget {
  const Monitoring({super.key});

  @override
  State<Monitoring> createState() => _MonitoringState();
}

class _MonitoringState extends State<Monitoring> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchTotalData();
  }

  Future<Map<String, dynamic>> _fetchTotalData() async {
    try {
      final response = await http.get(
        Uri.parse('${UserSession().baseUrl}/api/image/category-stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserSession().token}',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载出错：${response.statusCode}')));
        throw Exception('网络错误: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载出错：$e')));
      throw Exception('统计出错: $e');
    }
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _fetchTotalData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '数据统计',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          const SizedBox(width: 25),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '刷新数据',
          ),
          const SizedBox(width: 15),
          // SizedBox(
          //   width: 130,
          //   height: 43,
          //   child: ElevatedButton(
          //     onPressed: () => {Navigator.pushNamed(context, '/categoryManagement')},
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.orange,
          //       foregroundColor: Colors.white,
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(8),
          //       ),
          //     ),
          //     child: const Text('类目管理', style: TextStyle(fontSize: 16)),
          //   ),
          // ),
          const SizedBox(width: 20),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('错误: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data['code'] == 200) {
              return _buildDataTree(data['data']['data']);
            } else {
              return Center(child: Text('API错误: ${data['message']}'));
            }
          } else {
            return const Center(child: Text('没有数据'));
          }
        },
      ),
    );
  }

  Widget _buildDataTree(List<dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...data.map((category) => _buildCategoryCard(category, 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> node, int level) {
    final List<Color> levelColors = [
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
    ];

    final color = levelColors[level % levelColors.length];
    final isLastLevel = level >= 3; // 最多4级，这是最后一级

    // 安全获取count值
    final count = node['count'] is int ? node['count'] : 0;

    // 安全获取name值
    String name = node['name']?.toString() ?? '未知名称';
    if (level == 3) {
      name = ImageState.getDifficulty(int.parse(name));
    }
    return Card(
      color: color,
      margin: EdgeInsets.only(left: level * 16.0, bottom: 8.0),
      child: _buildExpandableTile(node, level, name, count, color, isLastLevel),
    );
  }

  Widget _buildExpandableTile(
    Map<String, dynamic> node,
    int level,
    String name,
    int count,
    Color color,
    bool isLastLevel,
  ) {
    // 使用状态管理来控制展开/折叠，避免使用ExpansionTile的兼容性问题
    return _CustomExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: level == 0 ? 18 : 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Chip(label: Text(count.toString()), backgroundColor: Colors.white),
        ],
      ),
      children: isLastLevel ? [] : _getChildren(node, level + 1),
      levelColor: color,
    );
  }

  List<Widget> _getChildren(Map<String, dynamic> node, int level) {
    String childrenKey;

    switch (level) {
      case 1:
        childrenKey = 'collector_types';
        break;
      case 2:
        childrenKey = 'question_directions';
        break;
      case 3:
        childrenKey = 'difficulties';
        break;
      default:
        return [];
    }

    if (node.containsKey(childrenKey) && node[childrenKey] is List) {
      return (node[childrenKey] as List).map<Widget>((child) {
        return _buildCategoryCard(child, level);
      }).toList();
    }

    return [];
  }
}

// 可展开Tile组件
class _CustomExpansionTile extends StatefulWidget {
  final Widget title;
  final List<Widget> children;
  final Color levelColor;

  const _CustomExpansionTile({
    required this.title,
    required this.children,
    required this.levelColor,
  });

  @override
  __CustomExpansionTileState createState() => __CustomExpansionTileState();
}

class __CustomExpansionTileState extends State<_CustomExpansionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: widget.title,
          trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          tileColor: widget.levelColor,
        ),
        if (_isExpanded) ...widget.children,
      ],
    );
  }
}
