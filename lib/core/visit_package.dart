class VisitPackage {
  VisitPackage({
    required this.id,
    required this.name,
    required this.totalPrice,
  }) {
    if (name.trim().isEmpty || !totalPrice.isFinite || totalPrice < 0) {
      throw const FormatException('请填写套餐名称和有效总价');
    }
  }

  final String id;
  final String name;
  final double totalPrice;

  factory VisitPackage.fromJson(Map<String, dynamic> json) => VisitPackage(
    id: json['id'] as String,
    name: json['name'] as String,
    totalPrice: (json['totalPrice'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'totalPrice': totalPrice,
  };
}
