import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/tools/work_state.dart';
import 'package:qa_imageprocess/user_session.dart';

//Work列表
class WorkList extends StatefulWidget {
  const WorkList({super.key});

  @override
  State<WorkList> createState() => _WorkListState();
}

class _WorkListState extends State<WorkList> {
  // 工作列表状态
  List<WorkModel> _works = [];

  int _totalPages = 1;
  int _totalItems = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String _errorMessage = '';

  // 状态统计
  Map<int, int> _statusCounts = {
    0: 0, // 未采集
    1: 0, // 正在采集
    2: 0, // 采集完成
    3: 0, // 等待质检
    4: 0, // 正在质检
    5: 0, // 质检打回
    6: 0, // 质检通过
    7: 0, // 等待交付
    8: 0, // 交付完成
  };

  // 分页参数
  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动监听器，用于无限滚动
  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      _loadMoreData();
    }
  }

  // 加载初始数据
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _works = [];
      _hasMore = true;
      // 重置状态计数
      _statusCounts = {
        0: 0, // 未采集
        1: 0, // 正在采集
        2: 0, // 采集完成
        3: 0, // 等待质检
        4: 0, // 正在质检
        5: 0, // 质检打回
        6: 0, // 质检通过
        7: 0, // 等待交付
        8: 0, // 交付完成
      };
    });

    try {
      await _fetchWorks(_currentPage);
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

  // 加载更多数据
  Future<void> _loadMoreData() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchWorks(_currentPage + 1);
    } catch (e) {
      setState(() {
        _errorMessage = '加载更多数据失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 获取工作列表API调用
  Future<void> _fetchWorks(int page) async {
    final url = Uri.parse(
      '${UserSession().baseUrl}/api/works/user-works?page=$page&pageSize=$_pageSize',
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
        final pagination = workData['pagination'];

        // 更新状态计数
        // 创建新的状态计数Map，初始化为0
        final newStatusCounts = Map<int, int>.from(_statusCounts);
        final newWorks = (workData['works'] as List)
            .map((workJson) => WorkModel.fromJson(workJson))
            .toList();

        // 统计新工作项的状态
        for (final work in newWorks) {
          newStatusCounts[work.state] = (newStatusCounts[work.state] ?? 0) + 1;
        }

        setState(() {
          _currentPage = pagination['currentPage'];
          _totalItems = pagination['totalItems'];

          // 添加新工作项
          _works.addAll(newWorks);

          // 更新状态计数
          _statusCounts = newStatusCounts;

          // 检查是否还有更多数据
          _hasMore = _currentPage < pagination['totalPages'];
        });
      } else {
        throw Exception('API错误: ${data['message']}');
      }
    } else {
      throw Exception('HTTP错误: ${response.statusCode}');
    }
  }

  // 放弃任务API调用
  Future<void> _abandonWork(int workID) async {
    final url = Uri.parse('${UserSession().baseUrl}/api/works/abandon');

    final headers = {
      'Authorization': 'Bearer ${UserSession().token}',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.delete(
        url,
        headers: headers,
        body: jsonEncode({'workID': workID}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('任务 $workID 已放弃'),
              backgroundColor: Colors.green,
            ),
          );

          // 重新加载数据
          _loadInitialData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('放弃任务失败: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请求失败: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    // if (_works.isEmpty && !_isLoading) {
    //   return const Center(child: Text('暂无工作数据'));
    // }

    return Column(
      children: [
        // 顶部统计信息
        Row(
          children: [
            _buildSummaryCard(),
            SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInitialData,
              tooltip: '刷新',
            ),
          ],
        ),

        // 工作列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _works.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _works.length) {
                return _buildLoader();
              }
              return _buildWorkItem(_works[index]);
            },
          ),
        ),
      ],
    );
  }

  // 顶部统计卡片 - 显示任务总数和各种状态的数量
  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总任务数
            Text(
              '总任务数: $_totalItems',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 状态统计
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusCounts.entries.map((entry) {
                final state = entry.key;
                final count = entry.value;

                return Chip(
                  label: Text(
                    '${WorkModel.getWorkState(state)}: $count',
                    style: const TextStyle(fontSize: 14),
                  ),
                  backgroundColor: WorkModel.getWorkStateColor(
                    state,
                  ).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: WorkModel.getWorkStateColor(state),
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: WorkModel.getWorkStateColor(state),
                      width: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 加载指示器
  Widget _buildLoader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _hasMore
            ? const CircularProgressIndicator()
            : const Text('没有更多数据了'),
      ),
    );
  }

  // 工作项卡片
  Widget _buildWorkItem(WorkModel work) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：ID和状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '任务 ID: ${work.workID}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusBadge(work.state),
              ],
            ),

            const SizedBox(height: 2),

            // 任务信息 - 改为双列布局
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左列：管理员和类目
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWorkInfoRow('管理员', work.admin.name),
                      _buildWorkInfoRow('类目', work.category),
                    ],
                  ),
                ),

                // 右列：采集类型、问题方向和难度
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildWorkInfoRow('采集类型', work.collectorType),
                      _buildWorkInfoRow('问题方向', work.questionDirection),
                      _buildWorkInfoRow(
                        '难度',
                        WorkModel.getDifficulty(work.difficulty),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 进度条
            _buildProgressBar(work),

            const SizedBox(height: 2),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (work.state == 0 || work.state == 1) // 未采集或正在采集可放弃
                  TextButton(
                    onPressed: () => _showAbandonDialog(work.workID),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('放弃'),
                  ),
                const SizedBox(width: 8),
                if (work.state != 3)
                  ElevatedButton(
                    onPressed: () => {_handleSubmit(work, 3)},
                    child: const Text('提交'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _viewWorkDetails(work),
                  child: const Text('查看'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit(WorkModel work, int newStatus) async {
    await WorkState.submitWork(
      context,
      work,
      newStatus,
      onSuccess: (updatedWork) {
        setState(() {
          // _currentWork = updatedWork;
          _works = _works.map((work) {
            if (work.workID == updatedWork.workID) {
              return updatedWork;
            }
            return work;
          }).toList();
        });
        // 可以在这里添加更多成功处理逻辑
        print("任务更新成功，新状态: ${updatedWork.state}");
      },
      onError: (error) {
        // 错误处理
        print("任务更新失败$error");
      },
    );
  }

  // 状态标签
  Widget _buildStatusBadge(int state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: WorkModel.getWorkStateColor(state).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkModel.getWorkStateColor(state)),
      ),
      child: Text(
        WorkModel.getWorkState(state),
        style: TextStyle(
          color: WorkModel.getWorkStateColor(state),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 任务信息行
  Widget _buildWorkInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // 进度条
  Widget _buildProgressBar(WorkModel work) {
    final progress = work.currentCount / work.targetCount;
    final percentage = (progress * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '完成进度: $percentage%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${work.currentCount}/${work.targetCount}'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress == 1 ? Colors.green : Theme.of(context).primaryColor,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }

  // 放弃任务确认对话框
  void _showAbandonDialog(int workID) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认放弃任务'),
          content: const Text('确定要放弃这个任务吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _abandonWork(workID);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('确认放弃'),
            ),
          ],
        );
      },
    );
  }

  // 查看任务详情（占位函数）
  void _viewWorkDetails(WorkModel work) {
    // TODO: 实现查看任务详情功能
    Navigator.pushNamed(
      context,
      '/workDetail',
      arguments: {'workID': work.workID},
    );
  }
}
