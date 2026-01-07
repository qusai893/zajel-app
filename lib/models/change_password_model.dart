// models/change_password_model.dart
class ChangePasswordRequest {
  final int customerId;
  final String oldPassword;
  final String newPassword;

  ChangePasswordRequest({
    required this.customerId,
    required this.oldPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    };
  }
}

class ChangePasswordResponse {
  final bool success;
  final String message;

  ChangePasswordResponse({
    required this.success,
    required this.message,
  });

  factory ChangePasswordResponse.fromJson(Map<String, dynamic> json) {
    return ChangePasswordResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
