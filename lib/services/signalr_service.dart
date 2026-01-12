import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SignalRService {
  late HubConnection hubConnection;
  static String serverUrl = dotenv.env['AUTH_HUB_URL'] ?? "";

  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  bool _isInitialized = false;

  // onLogout fonksiyonunu sınıf seviyesinde saklayalım ki dışarıdan tetikleyebilelim
  Function? _logoutCallback;

  Future<void> initSignalR(
      int userId, BuildContext context, Function onLogout) async {
    // Callback'i kaydet
    _logoutCallback = onLogout;

    if (_isInitialized) return;

    final httpConnectionOptions = HttpConnectionOptions(
      skipNegotiation: false,
      requestTimeout: 60000,
    );

    hubConnection = HubConnectionBuilder()
        .withUrl(serverUrl, options: httpConnectionOptions)
        .withAutomaticReconnect(
            retryDelays: [0, 2000, 5000, 10000, 30000]).build();

    hubConnection.serverTimeoutInMilliseconds = 60000;
    hubConnection.keepAliveIntervalInMilliseconds = 15000;

    // --- EVENT LISTENERLAR ---

    // 1. Mevcut: Yeni Giriş İsteği
    hubConnection.on("NewLoginAttempt", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _showApprovalDialog(context, data, onLogout);
      }
    });

    // 2. 🔥 YENİ: Zorla Çıkış İsteği (Backend'den tetiklenecek)
    hubConnection.on("ForceLogout", (arguments) {
      print("⚠️ ForceLogout received from server");
      // UI Thread içinde çalıştır
      Future.delayed(Duration.zero, () {
        if (_logoutCallback != null) {
          _logoutCallback!(); // Ana çıkış fonksiyonunu çalıştır

          // Kullanıcıya bilgi ver (Opsiyonel)
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("تم تسجيل الدخول من جهاز آخر، تم تسجيل الخروج."),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      });
    });

    // ... Diğer connection listenerlar (onclose, onreconnecting vs. aynı kalabilir) ...

    try {
      await hubConnection.start();
      await _registerUser(userId);
      _isInitialized = true;
      print("✅ SignalR Connected - User: $userId");
    } catch (e) {
      print("❌ SignalR Error: $e");
      _isInitialized = false;
    }
  }

  Future<void> _registerUser(int userId) async {
    try {
      if (hubConnection.state == HubConnectionState.Connected) {
        await hubConnection.invoke("RegisterUser", args: [userId.toString()]);
      }
    } catch (e) {
      print("❌ RegisterUser Error: $e");
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await hubConnection.stop();
      _isInitialized = false;
    }
  }

  void _showApprovalDialog(
      BuildContext context, Map<String, dynamic> data, Function onLogout) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("تنبيه أمان",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(
          "هناك محاولة تسجيل دخول من جهاز جديد:\n[${data['NewDeviceAndroidId']}]\n\nهل تسمح لهذا الجهاز بالدخول وتسجيل خروجك؟",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("لا، ارفض", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.currentCustomer == null) return;

              // Dialogu hemen kapatma, işlem sonucunu bekle veya loading göster
              // Basitlik için burada kapatıyoruz ama hata olursa kullanıcıya bildirmeliyiz.
              Navigator.of(ctx).pop();

              try {
                bool result = await ApiService.approveDeviceLogin(
                    authProvider.currentCustomer!.cusId,
                    data['NewDeviceAndroidId'],
                    true);

                if (result) {
                  // Başarılı olursa API zaten SignalR üzerinden "ForceLogout" gönderecek.
                  // Ama garanti olsun diye burada da çağırabiliriz.
                  print("✅ Approval sent successfully");
                  // onLogout(); // Bunu "ForceLogout" eventine bıraktık ama istersen burada da dursun.
                } else {
                  // Hata durumunda kullanıcıya bildir
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              "فشلت عملية الموافقة، يرجى المحاولة مرة أخرى"),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("خطأ: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("نعم، اسمح له",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
