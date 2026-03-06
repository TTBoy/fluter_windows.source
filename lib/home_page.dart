// 添加必要的导入
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/navi/app_navigation_drawer.dart';
import 'package:qa_imageprocess/pages/allimage.dart';
import 'package:qa_imageprocess/pages/get_repeated_image.dart';
import 'package:qa_imageprocess/pages/management_page.dart';
import 'package:qa_imageprocess/pages/monitoring.dart';
import 'package:qa_imageprocess/pages/review_list.dart';
import 'package:qa_imageprocess/pages/work_list.dart';
import 'package:qa_imageprocess/pages/work_manager.dart';
import 'package:qa_imageprocess/tools/updateCheck.dart';
import 'package:qa_imageprocess/user_session.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // 自动保存状态
  @override
  bool get wantKeepAlive => true;

  int _selectedIndex = 0;

  // 使用PageStorageKey为每个页面保存独立状态
  final List<PageStorageKey> _pageKeys = [
    PageStorageKey('page0'),
    PageStorageKey('page1'),
    PageStorageKey('page2'),
    PageStorageKey('page3'),
    PageStorageKey('page4'),
    PageStorageKey('page5'),
    PageStorageKey('page6'),
    PageStorageKey('page7'),
  ];

  // 用户信息
  Map<String, dynamic> _userInfo = {
    'name': '加载中...',
    'email': '加载中...',
    'avatar': Icons.person,
    'role': '',
    'joinDate': '',
  };

  late List<String> _pageTitles;
  late List<Widget> _pages;
  bool _isLoading = true; // 添加加载状态

  @override
  void initState() {
    super.initState();
    // 初始化用户信息和页面列表
    _pageTitles = [];
    _pages = [];
    _initializeUserInfo();
    UpdateChecker.checkForUpdate(context);
  }

  // 初始化用户信息
  void _initializeUserInfo() async {
    try {
      final userSession = UserSession();
      // 确保加载完成
      await userSession.loadFromPrefs();

      // 从UserSession获取用户角色
      final role = userSession.role;
      final name = userSession.name;
      final email = userSession.email;

      // 添加日志输出，帮助调试角色问题
      print('token=${userSession.token}');

      // 更新用户信息
      setState(() {
        _userInfo = {
          'name': name ?? '未知',
          'email': email ?? '未知',
          'avatar': Icons.person,
          'role': role == 1 ? '管理员' : '普通用户', // 根据数字显示角色名称
          'joinDate': '2024-01-01',
        };
      });

      // 初始化页面列表 - 使用数字角色判断
      // bool isAdmin = role == 1;
      // bool isQualityInspection= role ==2;
      _initializePages(role??0);
    } catch (e) {
      _showMessage('初始化用户信息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 根据用户角色初始化页面列表
  void _initializePages(int role) {
    // 创建页面实例 - 使用GlobalKey保存状态
    final basePages = [
      {'title': 'Work', 'page': WorkList(key: _pageKeys[0])},
      
      {'title': '查重', 'page': GetRepeatedImage(key: _pageKeys[2])},
    ];

    //质检人员或者管理员界面
    if(role==2||role==1){
      basePages.add({'title': '质检', 'page': ReviewList(key: _pageKeys[1])});
      basePages.add({'title': '任务管理', 'page': WorkManager(key: _pageKeys[4])});
    }

    // 只有管理员
    if (role==1) {
      basePages.add({
        'title': '账号管理',
        'page': ManagementPage(key: _pageKeys[3]),
      });
      
      basePages.add({'title': '总览', 'page': Allimage(key: _pageKeys[5])});
      basePages.add({'title':'统计','page':Monitoring(key: _pageKeys[6])});
    }

    // 更新页面和标题列表
    setState(() {
      _pageTitles = basePages.map((item) => item['title'] as String).toList();
      _pages = basePages.map((item) => item['page'] as Widget).toList();
    });
  }

  /// 显示消息提示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleUserMenu() async {
    showDialog(
      context: context,
      builder: (context) {
        bool showReset = false;
        String currentPwd = '';
        String newPwd = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('我的用户信息'),
              content: SizedBox(
                width: double.minPositive,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 用户基本信息
                    ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: Text(UserSession().name ?? '未知'),
                      subtitle: Text('${UserSession().email}'),
                    ),
                    const SizedBox(height: 16),
                    // 初始只显示“重置密码”按钮
                    if (!showReset)
                      ElevatedButton(
                        onPressed: () => setState(() => showReset = true),
                        child: const Text('重置密码'),
                      ),
                    // 展开密码重置表单
                    if (showReset) ...[
                      TextField(
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '当前密码',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => currentPwd = value,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '新密码',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => newPwd = value,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('token');
                          if (token == null) {
                            _showMessage('未登录');
                            return;
                          }
                          try {
                            final resp = await http.put(
                              Uri.parse(
                                '${UserSession().baseUrl}/api/user/change-password',
                              ),
                              headers: {
                                'Authorization': 'Bearer $token',
                                'Content-Type': 'application/json',
                              },
                              body: jsonEncode({
                                'oldPassword': currentPwd,
                                'newPassword': newPwd,
                              }),
                            );
                            //  print(resp.body);
                            if (resp.statusCode == 200) {
                              _showMessage('密码重置成功');
                              Navigator.of(context).pop();
                            } else {
                              _showMessage('重置失败：${resp.body}');
                            }
                          } catch (e) {
                            _showMessage('网络错误：$e');
                          }
                        },
                        child: const Text('提交'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  //打开设置界面
  void _toggleSettings() {
    Navigator.pushNamed(context, '/systemSet');
  }
  
  //退出
  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    // 退出后导航到登录页面
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Row(
        children: [
          // 使用新的导航栏组件
          AppNavigationDrawer(
            userInfo: _userInfo,
            pageTitles: _pageTitles,
            selectedIndex: _selectedIndex,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
            onToggleUserMenu: () => {_toggleUserMenu()},
            onToggleSettings: _toggleSettings,
            onLogout: logout,
            getIconForIndex: _getIconForIndex,
          ),

          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(index: _selectedIndex, children: _pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 根据索引获取对应的图标
  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.work;
      case 1:
        return Icons.search;
      case 2:
        return Icons.title;
      case 3:
        return Icons.people;
      case 4:
        return Icons.image_outlined;
      case 5:
        return Icons.view_agenda;
      case 6:
        return Icons.data_array;
      case 7:
        return Icons.admin_panel_settings;
      default:
        return Icons.question_mark;
    }
  }
}
