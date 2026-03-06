import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/work_model.dart';
import 'package:qa_imageprocess/user_session.dart';

class WorkState {
  /// 提交工作任务并更新状态
  static Future<void> submitWork(
    BuildContext context,
    WorkModel work,
    int state, 
    {
    String? returnReason,
    String? remark,
    ValueChanged<WorkModel>? onSuccess,
    ValueChanged<Exception>? onError,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${UserSession().baseUrl}/api/works/status/${work.workID}'),
        headers: {
          'Authorization': 'Bearer ${UserSession().token ?? ''}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'state': state,
          'returnReason':returnReason,
          'remark':remark,
        }),
      );

      print('API响应: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] == null) {
          throw FormatException('API响应缺少数据字段');
        }
        final updatedWork = WorkModel.fromJson(jsonData['data']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交成功'))
        );
        if (onSuccess != null) onSuccess(updatedWork);
      } else {
        final errorJson = json.decode(response.body);
        final errorMessage = errorJson['message'] ?? '未知错误';
        final statusMessage = '提交失败 (${response.statusCode}): $errorMessage';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusMessage))
        );
        

      }
    } catch (e) {
      final errorMsg = '提交出错: ${e.toString()}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg))
      );

    }
  }
}

