import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zajel/models/customer.dart';
import 'package:zajel/models/transfer_model.dart';
import 'package:zajel/models/customer_balance_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String baseUrl = dotenv.env['BASE_URL'] ?? "";

  static String _handleError(dynamic e) {
    if (e is SocketException || e is http.ClientException) {
      return "لا يوجد اتصال بالإنترنت، يرجى التحقق من الشبكة"; // İnternet bağlantısı yok
    } else if (e is TimeoutException) {
      return "انتهت مهلة الاتصال بالخادم، يرجى المحاولة لاحقاً"; // Zaman aşımı
    } else {
      return "حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى"; // Beklenmedik hata
    }
  }

  // Cache bypass için timestamp ekle
  static String _getCacheBustingUrl(String endpoint) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final separator = endpoint.contains('?') ? '&' : '?';
    return '$endpoint${separator}_t=$timestamp';
  }

  static Future<Map<String, String>> _getHeaders({bool noCache = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (noCache) ...{
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }
    };
  }

  static Future<Map<String, dynamic>> getTransferSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/Transfer/settings'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load settings');
  }

  static Future<String> generateNotificationNumber() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/transfer/generate-notification'),
              headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200)
        return json.decode(response.body)['notificationNumber'];
      throw Exception("فشل في إنشاء رقم الإشعار");
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  static Future<Map<String, dynamic>> getDailyStats() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/Transfer/daily-stats'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 30)); // Zaman aşımı ekleyin

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception(
            'Login session has been expired, Please login and try again');
      } else {
        throw Exception('Error Code: ${response.statusCode}');
      }
    } catch (e) {
      print("API Error (getDailyStats): $e");
      rethrow; // Hatayı yukarı fırlat ki UI'da görebilelim
    }
  }

  // ⭐ Bakiye çekme fonksiyonu
  static Future<CustomerBalance?> getCustomerBalance(int userId) async {
    try {
      final headers = await _getHeaders(noCache: true);
      final url =
          Uri.parse(_getCacheBustingUrl('$baseUrl/transfer/balances/$userId'));

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return CustomerBalance.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        await logout();
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error in getCustomerBalance: $e');
      return null;
    }
  }

  // ⭐ Transfer gönderme
  static Future<Map<String, dynamic>> sendTransfer(
      Map<String, dynamic> transferData) async {
    try {
      final headers = await _getHeaders(noCache: true);
      final url = Uri.parse('$baseUrl/Transfer/send-transfer');

      final response = await http
          .post(
            url,
            headers: headers,
            body: json.encode(transferData),
          )
          .timeout(const Duration(seconds: 30));

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseBody.containsKey('token')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', responseBody['token']);
        }
        return responseBody;
      } else {
        return {
          "success": false,
          "message": responseBody['message'] ??
              responseBody['error'] ??
              "حدث خطأ أثناء إرسال الحوالة"
        };
      }
    } catch (e) {
      return {"success": false, "message": _handleError(e)};
    }
  }

  // ⭐ Sender info
  static Future<Map<String, dynamic>?> getSenderInfo() async {
    try {
      final headers = await _getHeaders(noCache: true);
      final url =
          Uri.parse(_getCacheBustingUrl('$baseUrl/transfer/sender-info'));

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await logout();
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error in getSenderInfo: $e');
      return null;
    }
  }

  // ⭐ Cihaz onayı
  static Future<bool> approveDeviceLogin(
      int customerId, String newAndroidId, bool isApproved) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/Auth/approve-device-login'),
            headers: headers,
            body: json.encode({
              // Backend'deki DeviceApprovalRequest modelindeki isimlerle birebir aynı olmalı
              'NewAndroidId': newAndroidId,
              'IsApproved': isApproved
            }),
          )
          .timeout(const Duration(seconds: 15));

      // Debug için log ekleyelim
      debugPrint("Approve Response Status: ${response.statusCode}");
      debugPrint("Approve Response Body: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Approve Device Error: $e");
      return false;
    }
  }

  // ⭐ Bağlantı testi
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Auth/test-connection'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ⭐ Giriş (Login)
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/Auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token'] ?? '');
          await prefs.setString('user', json.encode(data['customer']));
          await prefs.setString(
              'last_balance_update', DateTime.now().toIso8601String());
          return data;
        } else {
          throw Exception(data['message'] ?? 'بيانات الدخول غير صحيحة');
        }
      } else if (response.statusCode == 401 ||
          response.statusCode == 400 ||
          response.statusCode == 404) {
        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      } else {
        throw Exception('حدث خطأ في الخادم، يرجى المحاولة لاحقاً');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains("Exception:")) throw e;
      throw Exception(_handleError(e));
    }
  }

  static Future<void> saveAuthData(
      String token, Map<String, dynamic> customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user', json.encode(customer));
    await prefs.setString(
        'last_balance_update', DateTime.now().toIso8601String());
  }

  // ⭐ Şehirleri getir
  static Future<List<dynamic>> getCities() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/transfer/cities'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception("تعذر تحميل قائمة المدن");
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // ⭐ Komisyon hesapla
  static Future<Map<String, dynamic>> calculateFee(
      int amount, String currency) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/transfer/calculate-fee'),
            headers: headers,
            body: json.encode({'amount': amount, 'currency': currency}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception("تعذر حساب الرسوم");
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // ⭐ Bildirim numarası oluştur

  // ⭐ Alıcı kontrolü
  static Future<bool> checkReceiverExists(
      String firstName, String fatherName, String lastName) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/transfer/check-receiver'),
            headers: headers,
            body: json.encode({
              'firstName': firstName,
              'fatherName': fatherName,
              'lastName': lastName
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200)
        return json.decode(response.body)['exists'] ?? false;
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('✅ Logout: Cache cleared');
  }

  // static Future<Map<String, dynamic>> qrLogin(
  //     String androidId, String qrSerial) async {
  //   try {
  //     final response = await http
  //         .post(
  //           Uri.parse('$baseUrl/qr-login'),
  //           headers: {'Content-Type': 'application/json'},
  //           body: jsonEncode({'androidId': androidId, 'qrCodeValue': qrSerial}),
  //         )
  //         .timeout(const Duration(seconds: 15));

  //     // EĞER BODY BOŞSA HATAYI YAKALA
  //     if (response.body.isEmpty) {
  //       return {"success": false, "message": "Sunucudan boş yanıt döndü."};
  //     }

  //     return jsonDecode(response.body);
  //   } catch (e) {
  //     return {"success": false, "message": _handleError(e)};
  //   }
  // }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    return userString != null ? json.decode(userString) : null;
  }

  // ⭐ Giden havalar
  static Future<Map<String, dynamic>> getSentTransfers() async {
    try {
      final headers = await _getHeaders(noCache: true);
      final response = await http
          .get(
              Uri.parse(
                  _getCacheBustingUrl('$baseUrl/transfer/sent-transfers')),
              headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) return json.decode(response.body);
      if (response.statusCode == 401)
        throw Exception('انتهت صلاحية الجلسة، يرجى تسجيل الدخول');
      throw Exception('تعذر جلب الحوالات المرسلة');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // ⭐ Gelen havalar
  static Future<Map<String, dynamic>> getReceivedTransfers() async {
    try {
      final headers = await _getHeaders(noCache: true);
      final response = await http
          .get(
              Uri.parse(
                  _getCacheBustingUrl('$baseUrl/transfer/received-transfers')),
              headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('تعذر جلب الحوالات المستلمة');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  static Future<List<TransferModel>> getAllTransfers() async {
    try {
      final headers = await _getHeaders(noCache: true);

      final sentResponse = await http
          .get(
              Uri.parse(
                  _getCacheBustingUrl('$baseUrl/transfer/sent-transfers')),
              headers: headers)
          .timeout(const Duration(seconds: 20));
      final receivedResponse = await http
          .get(
              Uri.parse(
                  _getCacheBustingUrl('$baseUrl/transfer/received-transfers')),
              headers: headers)
          .timeout(const Duration(seconds: 20));

      List<TransferModel> transfers = [];
      //Sent Transfers
      if (sentResponse.statusCode == 200) {
        final data = json.decode(sentResponse.body);
        if (data['success'] == true) {
          transfers.addAll((data['transfers'] as List)
              .map((j) => TransferModel.fromJson(j, false, TransferType.sent)));
        }
      }
      //Received Transfers
      if (receivedResponse.statusCode == 200) {
        final data = json.decode(receivedResponse.body);
        if (data['success'] == true) {
          transfers.addAll((data['transfers'] as List).map(
              (j) => TransferModel.fromJson(j, true, TransferType.received)));
        }
      }

      transfers.sort((a, b) => b.date.compareTo(a.date));
      return transfers;
    } catch (e) {
      debugPrint('❌ Error in getAllTransfers: $e');
      return [];
    }
  }

  // ⭐ Şifre değiştirme
  static Future<Map<String, dynamic>> changePassword({
    required int customerId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/Auth/change-password'),
            headers: headers,
            body: json.encode({
              'customerId': customerId,
              'oldPassword': oldPassword,
              'newPassword': newPassword
            }),
          )
          .timeout(const Duration(seconds: 25));

      final data = json.decode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['message'] ?? 'فشل تغيير كلمة المرور');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }
}
