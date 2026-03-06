import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/user.dart';

class WorkModel {
  final int workID;
  final int adminID;
  final int workerID;
  final String category;
  final String collectorType;
  final String questionDirection;
  final int difficulty;
  final int state;
  final String? returnReason;
  final String? remark;
  final int targetCount;
  final int currentCount;
  final User admin;
  final User worker;
  final User? inspector;
  final String created_at;
  final String updated_at;

  WorkModel({
    required this.workID,
    required this.adminID,
    required this.workerID,
    required this.category,
    required this.collectorType,
    required this.questionDirection,
    required this.difficulty,
    required this.state,
    this.returnReason,
    this.remark,
    required this.targetCount,
    required this.currentCount,
    required this.admin,
    required this.worker,
    this.inspector,
    required this.created_at,
    required this.updated_at,
  });

  factory WorkModel.fromJson(Map<String, dynamic> json) {
    return WorkModel(
      workID: json['workID'] as int? ?? 0,
      adminID: json['adminID'] as int? ?? 0,
      workerID: json['workerID'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      collectorType: json['collector_type'] as String? ?? '',
      questionDirection: json['question_direction'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 0,
      state: json['state'] as int? ?? 0,
      returnReason: json['returnReason'] as String?,
      remark: json['remark'] as String?,
      targetCount: json['targetCount'] as int? ?? 0,
      currentCount: json['currentCount'] as int? ?? 0,
      admin: User.fromJson(json['admin'] as Map<String, dynamic>? ?? {}),
      worker: User.fromJson(json['worker'] as Map<String, dynamic>? ?? {}),
      inspector: User.fromJson(json['inspector'] as Map<String,dynamic>? ?? {}),
      created_at: json['created_at'] ?? '',
      updated_at: json['updated_at'] ?? '',
    );
  }
  //0：未采集，1：正在采集，2：采集完成，3：等待质检，4：正在质检，5：质检打回，6：质检通过，7：等待交付，8：交付完成
  static String getWorkState(int state) {
    switch (state) {
      case 0:
        return '未采集';
      case 1:
        return '正在采集';
      case 2:
        return '采集完成';
      case 3:
        return '等待质检';
      case 4:
        return '正在质检';
      case 5:
        return '质检打回';
      case 6:
        return '质检通过';
      case 7:
        return '等待交付';
      case 8:
        return '交付完成';
      default:
        return '未知';
    }
  }

  static Color getWorkStateColor(int state) {
    switch (state) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.blueAccent;
      case 5:
        return Colors.red;
      case 6:
        return Colors.greenAccent;
      case 7:
        return Colors.purple;
      case 8:
        return Colors.teal;
      default:
        return Colors.black;
    }
  }

    static String getDifficulty(int difficulty) {
    switch (difficulty) {
      case 0:
        return '简单';
      case 1:
        return '中等';
      case 2:
        return '困难';
      default:
        return '未知';
    }
  }
}
