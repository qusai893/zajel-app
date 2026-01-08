import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/device_auth_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DeviceAuthService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "";
  //static const String baseUrl = 'http://192.168.100.40:5000/api';

  Future<DeviceAuthResponse?> checkDevice(String androidId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Auth/check-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'androidId': androidId}),
      );

      print(
          "CheckDevice Response: ${response.body}"); // Debug için bunu mutlaka gör

      if (response.statusCode == 200) {
        return DeviceAuthResponse.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print("CheckDevice Error: $e");
    }
    return null;
  }

  static String _handleError(dynamic e) {
    if (e is SocketException || e is http.ClientException) {
      return "لا يوجد اتصال بالإنترنت، يرجى التحقق من الشبكة"; // İnternet bağlantısı yok
    } else if (e is TimeoutException) {
      return "انتهت مهلة الاتصال بالخادم، يرجى المحاولة لاحقاً"; // Zaman aşımı
    } else {
      return "حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى"; // Beklenmedik hata
    }
  }

  Future<DeviceAuthResponse?> qrLogin(String androidId, String qrCode) async {
    try {
      // DÜZELTİLEN URL: baseUrl zaten /api/Auth içeriyor
      final url = Uri.parse('$baseUrl/Auth/qr-login');

      print("İstek atılan URL: $url"); // Debug için

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "AndroidId": androidId,
              "QrCodeValue": qrCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print("QR Login Status Code: ${response.statusCode}");
      print("QR Login Response Body: ${response.body}");

      if (response.body.isEmpty) {
        throw Exception("Server returned empty body");
      }

      final responseData = jsonDecode(response.body);
      return DeviceAuthResponse.fromJson(responseData);
    } catch (e) {
      print("QR Login API Error: $e");
      return DeviceAuthResponse(
        success: false,
        isDeviceRegistered: false,
        message: "تعذر الاتصال بالخادم: $e",
      );
    }
  }
}
