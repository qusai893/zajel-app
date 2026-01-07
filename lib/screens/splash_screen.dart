import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/device_auth_service.dart';
import '../main.dart';
import 'qr_login_screen.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final DeviceAuthService _authService = DeviceAuthService();

  @override
  void initState() {
    super.initState();
    _checkDeviceAndLogin();
  }

  Future<void> _checkDeviceAndLogin() async {
    await Future.delayed(const Duration(seconds: 1));
    String? androidId = await _getAndroidId();
    if (androidId == null) return;

    try {
      final result = await _authService.checkDevice(androidId);

      if (!mounted) return;

      if (result != null && result.success && result.isDeviceRegistered) {
        // BURAYA DİKKAT: result.customer'ın null olmadığından emin oluyoruz
        if (result.customer != null) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);

          // Token'ı ve Müşteriyi set ediyoruz
          authProvider.setToken(result.token ?? "");
          authProvider.setCustomer(result.customer!); // Map olarak gönderiliyor

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          _showError("الجهاز مسجل ولكن لم ترد معلومات المستخدم.");
        }
      } else if (result != null && !result.isDeviceRegistered) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => QrLoginScreen(androidId: androidId)),
        );
      } else {
        _showError(result?.message ?? "خطأ في الاتصال");
      }
    } catch (e) {
      _showError("حدث خطأ: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<String?> _getAndroidId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }
    } catch (e) {
      debugPrint("خطأ في الحصول على المعرف: $e");
    }
    return "unknown-device";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              "جار التحقق من الجهاز...",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
