// models/customer.dart
class Customer {
  final int cusId;
  final String? cusName;
  final String? cusLastName;
  final String? cusFatherName;
  double cusBalanceSyr;
  double cusBalanceDollar;
  final String? clientId;
  final String? regName;

  Customer({
    required this.cusId,
    this.cusName,
    this.cusFatherName,
    this.cusLastName,
    required this.regName,
    required this.cusBalanceSyr,
    required this.cusBalanceDollar,
    this.clientId,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      cusId: json['cusId'] ?? 0,
      cusName: json['cusName'] ?? '',
      cusFatherName: json['cusFatherName'] ?? '',
      cusLastName: json['cusLastName'] ?? json['CusLastName'] ?? '',
      cusBalanceSyr: (json['cusBalanceSyr'] as num?)?.toDouble() ?? 0.0,
      cusBalanceDollar: (json['cusBalanceDollar'] as num?)?.toDouble() ?? 0.0,
      clientId: json['clientId'] ?? '',
      regName: json['cityName'] ?? 'Bilinmiyor',
    );
  }

  // toJson method (isteğe bağlı)
  Map<String, dynamic> toJson() {
    return {
      'cusId': cusId,
      'cusName': cusName,
      'cusFatherName': cusFatherName,
      'CusLastName': {cusLastName ?? 'cusLastName': cusLastName},
      'cusBalanceSyr': cusBalanceSyr,
      'cusBalanceDollar': cusBalanceDollar,
      'clientId': clientId,
      'cityName': regName,
    };
  }
}
