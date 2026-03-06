import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:qa_imageprocess/model/release.dart';
import 'package:qa_imageprocess/user_session.dart';

//检查更新，检测最新版本
class UpdateChecker {
  static final String currentVersion = UserSession().version;

  // 检查更新
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('${UserSession().baseUrl}/api/releases/latest'),
      );

      // print(response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 检查API返回的code是否为0（成功）
        if (data['code'] == 200) {
          final latestRelease = Release.fromJson(data['data']);
          
          // 比较版本号
          if (_compareVersions(latestRelease.versionNumber, currentVersion) > 0) {
            // 显示更新对话框
            _showUpdateDialog(context, latestRelease);
          }else{
            print('版本检查正确');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败: ${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新出错: $e')),
      );
    }
  }

  // 比较版本号
  static int _compareVersions(String v1, String v2) {
    try {
      final v1Parts = v1.split('.').map(int.parse).toList();
      final v2Parts = v2.split('.').map(int.parse).toList();
      
      for (int i = 0; i < v1Parts.length; i++) {
        if (i >= v2Parts.length) return 1;
        if (v1Parts[i] > v2Parts[i]) return 1;
        if (v1Parts[i] < v2Parts[i]) return -1;
      }
      
      return v1Parts.length == v2Parts.length ? 0 : -1;
    } catch (e) {
      // 如果版本号格式不正确，使用字符串比较
      return v1.compareTo(v2);
    }
  }

  // 显示更新对话框
  static void _showUpdateDialog(BuildContext context, Release release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本: $currentVersion'),
              Text('最新版本: ${release.versionNumber}'),
              const SizedBox(height: 10),
              const Text('更新内容:'),
              Text(release.releaseLog),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _downloadAndInstall(context, release);
              },
              child: const Text('下载安装'),
            ),
          ],
        );
      },
    );
  }

  // 下载并安装
  static Future<void> _downloadAndInstall(BuildContext context, Release release) async {
    try {
      // 获取下载目录
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取下载目录')),
        );
        return;
      }
      
      // 创建文件路径
      final filePath = '${directory.path}/${release.softwareName}';
      final file = File(filePath);
      
      // 显示下载进度
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            title: Text('下载中'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在下载更新，请稍候...'),
              ],
            ),
          );
        },
      );
      
      // 下载文件
      final response = await http.get(
        Uri.parse('${UserSession().baseUrl}/imageQaRelease/${release.softwareName}'),
      );
      
      Navigator.of(context).pop(); // 关闭进度对话框
      
      if (response.statusCode == 200) {
        // 保存文件
        await file.writeAsBytes(response.bodyBytes);
        
        // 在Windows上运行安装程序
        if (Platform.isWindows) {
          Process.run('cmd', ['/c', 'start', '', filePath]);

          Future.delayed(const Duration(seconds: 1),(){
            exit(0);
          });
        } 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载完成，开始安装')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: ${response.statusCode}')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // 确保关闭进度对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载出错: $e')),
      );
    }
  }
}