import 'dart:ui';

import 'package:flutter/material.dart';

class Checkimageliststate {
  static String getCheckImageListState(int state) {
    switch (state) {
      case 0:
        return '未检查';
      case 1:
        return '正在检查';
      case 2:
        return '检查结束';
      default:
        return '';
    }
  }

  static Color getCheckImageListStateColor(int state) {
    switch (state) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
