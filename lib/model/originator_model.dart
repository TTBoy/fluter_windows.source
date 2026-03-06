class Originator {
  final int id;
  final String name;

  Originator({
    required this.id,
    required this.name,
  });

  factory Originator.fromJson(Map<String, dynamic> json) {
    return Originator(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'Originator(id: $id, name: $name)';
  }
}