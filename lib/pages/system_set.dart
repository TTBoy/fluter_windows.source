import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:qa_imageprocess/user_session.dart';


///系统设置界面
///版本信息部分有一个按钮，点击后可以进入上传安装包界面，可以查看各个版本的更新信息，需要输入密码      yjz147258       
///下载最新安装包功能不可用，之前的项目粘贴过来的代码，没删
///
class SystemSet extends StatefulWidget {
  const SystemSet({super.key});

  @override
  State<SystemSet> createState() => _SystemSetState();
}

class _SystemSetState extends State<SystemSet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseUrlController;
  late TextEditingController _apiUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _folderPathController;
  late TextEditingController _modelname;

  // 下载相关状态
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    final session = UserSession();
    _baseUrlController = TextEditingController(text: session.baseUrl);
    _apiUrlController = TextEditingController(text: session.apiUrl);
    _apiKeyController = TextEditingController(text: session.apiKey);
    _folderPathController = TextEditingController(text: session.getRepetPath);
    _modelname=TextEditingController(text: session.modelName);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _folderPathController.dispose();
    _modelname.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        setState(() {
          _folderPathController.text = selectedDirectory;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('路径选择失败: $e'))
        );
      }
    }
  }

    // 新增：复制Token到剪切板
  void _copyTokenToClipboard() {
    Clipboard.setData(ClipboardData(text: UserSession().token??''));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token已复制到剪切板')),
    );
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        await UserSession().saveSystemSettings(
          newBaseUrl: _baseUrlController.text,
          newApiUrl: _apiUrlController.text,
          newApiKey: _apiKeyController.text,
          newGetRepetPath: _folderPathController.text,
          newModelName: _modelname.text,
        );
        await UserSession().loadFromPrefs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('设置保存成功！'))
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e'))
          );
        }
      }
    }
  }

  // 下载安装包
  Future<void> _downloadInstaller() async {
    String? savePath = await FilePicker.platform.getDirectoryPath();
    if (savePath == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    final downloadUrl = 
      '${_baseUrlController.text}/exe/ImageProcess-setup-x64.exe';
    final saveFile = File('$savePath/ImageProcess-setup-x64.exe');

    try {
      final dio = Dio();
      await dio.download(
        downloadUrl,
        saveFile.path,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = count / total;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载完成！文件保存在: $savePath'))
        );
      }
    } catch (e) {
      setState(() {
        _downloadError = '下载失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统设置'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // 设置卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API设置',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const Divider(height: 30),
                          _buildTextField(
                            controller: _baseUrlController,
                            label: 'API 基础地址',
                            hint: 'http://your-server.com',
                            icon: Icons.http,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _apiUrlController,
                            label: '大模型地址',
                            hint: 'https://api.provider.com/v1/chat',
                            icon: Icons.chat,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _apiKeyController,
                            label: 'API 密钥',
                            hint: 'sk-xxxxxxxxxxxxxxxx',
                            icon: Icons.vpn_key,
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _modelname,
                            label: '模型名称',
                            hint: 'gemini-2.5-pro',
                            icon: Icons.model_training,
                          ),
                          // 新增Token显示区域 ------------------------
                          const SizedBox(height: 15),
                          Text(
                            '当前Token',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    UserSession().token??'', // 直接显示token
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Tooltip(
                                  message: '复制Token',
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.copy_outlined,
                                      size: 20,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    onPressed: _copyTokenToClipboard,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // 路径设置卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '查重设置',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          const Divider(height: 30),
                          Text(
                            '查重程序路径',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _folderPathController,
                                  decoration: InputDecoration(
                                    hintText: '请选择文件夹路径',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  ),
                                  readOnly: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.folder_open, size: 28),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.green[100],
                                ),
                                onPressed: _pickFolder,
                                tooltip: '选择文件夹',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // 操作按钮
                  _buildSaveButton(),

                  const SizedBox(height: 30),
                  
                  // 版本和下载卡片
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '版本信息',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                          const Divider(height: 30),
                          
                          // 版本号
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.deepPurple[500],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '当前版本: ${UserSession().version}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 12),
                              IconButton(onPressed: ()=>{_showDeveloperDialog()}, icon: Icon(Icons.developer_board),iconSize: 20,)
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 下载按钮
                          if (!_isDownloading) ...[
                            OutlinedButton.icon(
                              icon: Icon(
                                Icons.download_outlined,
                                color: Theme.of(context).primaryColor,
                              ),
                              
                              label: const Text('下载最新安装包'),
                              onPressed: _downloadInstaller,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                ),
                                backgroundColor: Colors.deepPurple[50],
                              ),
                            ),
                          ] else ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 进度条
                                LinearProgressIndicator(
                                  value: _downloadProgress,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '下载中 ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            )
                          ],
                          
                          if (_downloadError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _downloadError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeveloperDialog() {
  final TextEditingController _commandController = TextEditingController();
  bool _isCommandValid = true;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('开发者指令'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _commandController,
                  decoration: InputDecoration(
                    labelText: '输入指令',
                    errorText: _isCommandValid ? null : '指令不正确',
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true, // 隐藏输入内容
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _isCommandValid = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),

              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final command = _commandController.text.trim();
                  if (command == 'yjz147258') {
                    Navigator.pop(context); 
                    Navigator.pushNamed(context, '/developer');
                  } else {
                    setState(() {
                      _isCommandValid = false;
                    });
                  }
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    _commandController.dispose(); // 对话框关闭后清理控制器
  });
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: Colors.blue[500]),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请填写$label';
        }
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.save, size: 24),
      label: const Text('保存设置', style: TextStyle(fontSize: 17)),
      onPressed: _saveSettings,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }
}