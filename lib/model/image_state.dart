import 'dart:ui';
import 'package:flutter/material.dart';

class ImageState {
  static const ToBeChecked = 0; //未检查
  static const Checking = 1; //正在检查
  static const UnderReview = 2; //正在审核
  static const Approved = 3; //审核通过
  static const Abandoned = 4; //废弃
  static String getStateText(int? state) {
    switch (state) {
      case 0:
        return '未检查';
      case 1:
        return '正在检查';
      case 2:
        return '质检打回';
      case 3:
        return '检查通过';
      case 4:
        return '等待交付';
      case 5:
        return '已交付';
      case 6:
        return '废弃';
      default:
        return '未知状态';
    }
  }

  static Color getStateColor(int? state) {
    switch (state) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.green;
      case 4:
        return Colors.black;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
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

  static int getDifficultyValue(String difficulty) {
    switch (difficulty) {
      case '简单':
        return 0;
      case '中等':
        return 1;
      case '困难':
        return 2;
      default:
        return -1;
    }
  }
}
