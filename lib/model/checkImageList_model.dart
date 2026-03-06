class CheckimagelistModel {
  final int checkImageListID;
  final int userID;
  final int imageCount;
  final int accessCount;
  final String createdAt;
  final String updatedAt;
  final int state;

  CheckimagelistModel({
    required this.checkImageListID,
    required this.userID,
    required this.imageCount,
    required this.accessCount,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
  });

  // 添加copyWith方法
  CheckimagelistModel copyWith({
    int? checkImageListID,
    int? userID,
    int? imageCount,
    int? accessCount,
    String? createdAt,
    String? updatedAt,
    int? state,
  }) {
    return CheckimagelistModel(
      checkImageListID: checkImageListID ?? this.checkImageListID,
      userID: userID ?? this.userID,
      imageCount: imageCount ?? this.imageCount,
      accessCount: accessCount ?? this.accessCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      state: state ??this.state,
    );
  }

  // 可选：添加fromJson工厂方法
  factory CheckimagelistModel.fromJson(Map<String, dynamic> json) {
    return CheckimagelistModel(
      checkImageListID: json['checkImageListID'] as int,
      userID: json['userID'] as int,
      imageCount: json['imageCount'] as int,
      accessCount: json['accessCount'] as int,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      state: json['state'] as int,
    );
  }

  // 可选：添加toJson方法用于序列化
  Map<String, dynamic> toJson() {
    return {
      'checkImageListID': checkImageListID,
      'userID': userID,
      'imageCount': imageCount,
      'accessCount': accessCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'state':state,
    };
  }

  // 可选：添加toString方法便于调试
  @override
  String toString() {
    return 'CheckimagelistModel(checkImageListID: $checkImageListID, userID: $userID)';
  }
}