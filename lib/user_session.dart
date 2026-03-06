import 'package:shared_preferences/shared_preferences.dart';



///加载用户信息以及一些配置信息
///[role]：用户角色
///[baseUrl]：服务端地址
///[apiUrl]：大模型API地址，必须使用多模态视觉模型
///[apiKey]：大模型API密钥
///[modelName]：模型名称
///[getRepetPath]：查重查询的路径，需要到设置界面手动设置
///[version]：软件版本号
///////////////////////////////////////////
class UserSession {
  static final UserSession _instance = UserSession._internal();

  factory UserSession() => _instance;

  UserSession._internal();

  String? token;
  String? name;
  String? email;
  int? role;
  int? id;
  String baseUrl = 'http://10.0.2.24:3101';
  // String baseUrl='http://10.1.5.103:9000';
  String apiUrl = 'https://api.shubiaobiao.com/v1/chat/completions';
  String apiKey = 'sk-NHfglGBWKuzKXBH5kV55BtNJaxrjRp8lkvJ7qiWK3EqLitG4';
  String modelName='gemini-2.5-flash';
  String getRepetPath = '';
  String version='0.0.27';

  /// 保存设置的键值常量
  static const String _baseUrlKey = 'system_baseUrl';
  static const String _apiUrlKey = 'system_apiUrl';
  static const String _apiKeyKey = 'system_apiKey';
  static const String _getRepetPath = 'systemRepetPath';
  static const String _modelName='system_modelName';

  bool get isLoggedIn => token != null;

  /// 初始化时从 SharedPreferences 加载用户信息
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    //  prefs.clear();

    token = prefs.getString('token');
    name = prefs.getString('name');
    email = prefs.getString('email');
    role = prefs.getInt('role');
    id = prefs.getInt('userID');

    // 加载系统设置
    baseUrl = prefs.getString(_baseUrlKey) ?? baseUrl; // 保持默认值
    apiUrl = prefs.getString(_apiUrlKey) ?? apiUrl;
    apiKey = prefs.getString(_apiKeyKey) ?? apiKey;
    getRepetPath = prefs.getString(_getRepetPath) ?? getRepetPath;
    modelName=prefs.getString(_modelName) ?? modelName;
  }

  /// 新增：专用方法保存系统设置
  Future<void> saveSystemSettings({
    required String newBaseUrl,
    required String newApiUrl,
    required String newApiKey,
    required String newGetRepetPath,
    required String newModelName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_baseUrlKey, newBaseUrl);
    await prefs.setString(_apiUrlKey, newApiUrl);
    await prefs.setString(_apiKeyKey, newApiKey);
    await prefs.setString(_getRepetPath, newGetRepetPath);
    await prefs.setString(_modelName, newModelName);

    baseUrl = newBaseUrl;
    apiUrl = newApiUrl;
    apiKey = newApiKey;
    getRepetPath=newGetRepetPath;
    modelName=newModelName;
    UserSession().loadFromPrefs();
  }

  /// 登录时保存用户信息
  Future<void> saveToPrefs({
    required String newToken,
    required String newName,
    required String newEmail,
    required int newRole, // 修改为int类型
    required int newId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
    await prefs.setString('name', newName);
    await prefs.setString('email', newEmail);
    await prefs.setInt('role', newRole); // 修改为setInt
    await prefs.setInt('userID', newId);

    // 更新内存中的值
    token = newToken;
    name = newName;
    email = newEmail;
    role = newRole;
    id=newId;
  }

  /// 登出时清空所有缓存
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
