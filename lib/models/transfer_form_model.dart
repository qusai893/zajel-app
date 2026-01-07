// lib/models/transfer_form_model.dart
class TransferFormData {
  double amount;
  String currency;
  String fullName;
  String city;
  String notes;

  TransferFormData({
    this.amount = 0.0,
    this.currency = 'USD',
    this.fullName = '',
    this.city = '',
    this.notes = '',
  });
}

class City {
  final String id;
  final String name;
  final String country;

  City({
    required this.id,
    required this.name,
    required this.country,
  });
}
