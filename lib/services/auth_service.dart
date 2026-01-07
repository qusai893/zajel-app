import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  //static const String _baseUrl = 'http://192.168.100.40:5000/api';
  static const String baseUrl = 'https://nabhanco.com/api';

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Login/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usr_LOGIN_NAME': username,
          'usr_PASSWORD': password,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // API bağlantı testi
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Login/test'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
