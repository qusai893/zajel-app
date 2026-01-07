class CustomerBalance {
  final int customerId;
  final double balanceDollar;
  final double balanceSyr;

  CustomerBalance({
    required this.customerId,
    required this.balanceDollar,
    required this.balanceSyr,
  });

  factory CustomerBalance.fromJson(Map<String, dynamic> json) {
    return CustomerBalance(
      customerId: json['customerId'] ?? 0,
      // Backend'den int veya double gelebilir, güvenli dönüşüm:
      balanceDollar: (json['balanceDollar'] ?? 0).toDouble(),
      balanceSyr: (json['balanceSyr'] ?? 0).toDouble(),
    );
  }
}
