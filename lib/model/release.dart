// Release数据模型
class Release {
  final int releaseID;
  final String versionNumber;
  final String softwareName;
  final String releaseLog;
  final String releaseTime;

  Release({
    required this.releaseID,
    required this.versionNumber,
    required this.softwareName,
    required this.releaseLog,
    required this.releaseTime,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      releaseID: json['releaseID'],
      versionNumber: json['versionNumber'],
      softwareName: json['softwareName'],
      releaseLog: json['releaseLog'],
      releaseTime: json['releaseTime'],
    );
  }
}