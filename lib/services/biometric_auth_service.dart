import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static bool _isProcessing = false;

  Future<bool> authenticate() async {
    if (_isProcessing) return false;

    try {
      _isProcessing = true;

      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        print('❌ Biyometrik desteklenmiyor');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'يرجى التحقق من هويتك للوصول إلى التطبيق',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'تأكيد الهوية',
            cancelButton: 'إلغاء',
            biometricHint: 'استخدم بصمة الإصبع',
            biometricNotRecognized: 'لم يتم التعرف على البصمة',
            biometricSuccess: 'تم التحقق بنجاح',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: false, // PIN/Şifreye izin ver
          stickyAuth: true, // Sistem pencereleri açılınca auth'u bozma
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print('❌ Platform Hatası [${e.code}]: ${e.message}');
      return false;
    } finally {
      _isProcessing = false;
    }
  }
}
