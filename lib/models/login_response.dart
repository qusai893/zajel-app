import 'customer.dart';

class LoginResponse {
  final bool success;
  final String message;
  final Customer? customer;
  final String? token;

  LoginResponse({
    required this.success,
    required this.message,
    this.customer,
    this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      customer:
          json['customer'] != null ? Customer.fromJson(json['customer']) : null,
      token: json['token'],
    );
  }
}
