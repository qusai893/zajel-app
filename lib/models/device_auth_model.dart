class DeviceAuthResponse {
  final bool success;
  final bool isDeviceRegistered;
  final String message;
  final String? token;
  final Map<String, dynamic>? customer;

  DeviceAuthResponse({
    required this.success,
    required this.isDeviceRegistered,
    required this.message,
    this.token,
    this.customer,
  });

  factory DeviceAuthResponse.fromJson(Map<String, dynamic> json) {
    // 1. Durum: Bazı response'larda veri 'loginData' içinde geliyor olabilir (check-device gibi)
    final loginData = json['loginData'] as Map<String, dynamic>?;

    // 2. Başarı durumu: Ana dizinde 'success' yoksa loginData içindekine bak
    bool successStatus = json['success'] ?? loginData?['success'] ?? false;

    // 3. Cihaz kayıtlı mı: Ana dizinde 'isRegistered' yoksa success durumuna bak
    bool registered = json['isRegistered'] ??
        json['isDeviceRegistered'] ??
        (successStatus ==
            true); // Eğer giriş başarılıysa cihaz kayıtlı demektir.

    return DeviceAuthResponse(
      success: successStatus,
      isDeviceRegistered: registered,
      // Mesaj ana dizinde yoksa loginData'dan al
      message: json['message'] ?? loginData?['message'] ?? 'خطأ غير معروف',
      // Token ve Customer ana dizinde veya loginData içinde olabilir
      token: json['token'] ?? loginData?['token'],
      customer: json['customer'] ?? loginData?['customer'],
    );
  }
}
