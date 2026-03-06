import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qa_imageprocess/model/user.dart';
import 'dart:convert';
import 'package:qa_imageprocess/user_session.dart';


//账号管理界面，显示除自己外的所有用户，可以更改用户角色（普通用户，管理员），和状态（正常，禁用）
class ManagementPage extends StatefulWidget {
  const ManagementPage({super.key});

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  List<User> users = [];
  Set<int> selectedUserIds = {};
  bool isLoading = true;
  String? errorMessage;

  final String _baseUrl = UserSession().baseUrl;
  final String _token = UserSession().token ?? '';
  final int nowUserID = UserSession().id ?? 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // 获取用户列表
  Future<void> _fetchUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/all'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<User> fetchedUsers = (data['data'] as List)
            .map((userJson) => User.fromJson(userJson))
            .where((user) => user.userID != nowUserID)
            .toList();

        setState(() {
          users = fetchedUsers;
          selectedUserIds.clear();
        });
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '网络请求异常: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handleErrorResponse(http.Response response) {
    setState(() {
      switch (response.statusCode) {
        case 403:
          errorMessage = '权限不足';
          break;
        default:
          errorMessage = '服务器错误: ${response.statusCode}';
      }
    });
  }

  // 统一角色修改方法
  Future<void> _updateUserRole(int newRole) async {
    if (selectedUserIds.isEmpty) {
      setState(() {
        errorMessage = '请至少选择一个用户';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/role'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userIds': selectedUserIds.toList(),
          'role': newRole,
        }),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '更新角色失败: $e';
      });
    }
  }

  // 统一状态修改方法
  Future<void> _updateUserState(int newState) async {
    if (selectedUserIds.isEmpty) {
      setState(() {
        errorMessage = '请至少选择一个用户';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/state'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userIds': selectedUserIds.toList(),
          'state': newState,
        }),
      );

      if (response.statusCode == 200) {
        _fetchUsers();
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '更新状态失败: $e';
      });
    }
  }




  // 状态显示颜色
  Color _stateColor(int state) {
    return state == 0 ? Colors.green : Colors.red;
  }

  // 切换用户选择
  void _toggleUserSelection(int userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
  }

  // 显示角色修改对话框
  void _showRoleDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedRole = user.role ?? 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('修改角色'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('普通用户'),
                    value: 0,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('管理员'),
                    value: 1,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final currentSelected = selectedUserIds.toSet();
                    setState(() => selectedUserIds = {user.userID});

                    Navigator.pop(context);
                    _updateUserRole(selectedRole).then((_) {
                      setState(() => selectedUserIds = currentSelected);
                    });
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示状态修改对话框
  void _showStateDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) {
        int selectedState = user.state ?? 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('修改状态'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('正常'),
                    value: 1,
                    groupValue: selectedState,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedState = value);
                      }
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('禁用'),
                    value: 0,
                    groupValue: selectedState,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedState = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final currentSelected = selectedUserIds.toSet();
                    setState(() => selectedUserIds = {user.userID});

                    Navigator.pop(context);
                    _updateUserState(selectedState).then((_) {
                      setState(() => selectedUserIds = currentSelected);
                    });
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 构建批量操作按钮
  Widget _buildBatchActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (selectedUserIds.isNotEmpty) ...[
            // 角色修改按钮
            OutlinedButton(
              onPressed: () => _updateUserRole(1),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('设为管理员'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _updateUserRole(0),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('设为普通用户'),
            ),
            const SizedBox(width: 10),
            // 状态修改按钮
            OutlinedButton(
              onPressed: () => _updateUserState(0),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('设为正常'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _updateUserState(1),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('设为禁用'),
            ),
          ],
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          _buildBatchActions(),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                ? const Center(child: Text('没有可管理的用户'))
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserListItem(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(User user) {
    final isSelected = selectedUserIds.contains(user.userID);

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (_) => _toggleUserSelection(user.userID),
      ),
      title: Text(user.name),
      subtitle: Text(user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 角色显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              User.getUserRole(user.role??-1),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),

          // 状态显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _stateColor(user.state ?? 0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              User.getUserState(user.state??-1),
              style: TextStyle(
                fontSize: 12,
                color: _stateColor(user.state ?? 0),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 操作按钮
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'role',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('修改角色'),
                ),
              ),
              const PopupMenuItem(
                value: 'state',
                child: ListTile(
                  leading: Icon(Icons.switch_account),
                  title: Text('修改状态'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'role') {
                _showRoleDialog(context, user);
              } else if (value == 'state') {
                _showStateDialog(context, user);
              }
            },
          ),
        ],
      ),
      onTap: () => _toggleUserSelection(user.userID),
    );
  }
}
