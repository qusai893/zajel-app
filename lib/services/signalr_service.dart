import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'api_service.dart';

class SignalRService {
  late HubConnection hubConnection;
  final String serverUrl = "https://nabhanco.com/authHub";
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  bool _isInitialized = false;

  Future<void> initSignalR(
      int userId, BuildContext context, Function onLogout) async {
    if (_isInitialized) return;

    // 🔧 HttpConnectionOptions düzgün şekilde oluştur
    final httpConnectionOptions = HttpConnectionOptions(
      skipNegotiation: false,
      requestTimeout: 60000, // 60 saniye
    );

    hubConnection = HubConnectionBuilder()
        .withUrl(serverUrl, options: httpConnectionOptions) // ✅ Named parameter
        .withAutomaticReconnect(retryDelays: [
      0, 2000, 5000, 10000, 30000 // Yeniden bağlanma aralıkları (ms)
    ]).build();

    // 🔧 Timeout ayarları
    hubConnection.serverTimeoutInMilliseconds = 60000; // 60 saniye
    hubConnection.keepAliveIntervalInMilliseconds = 15000; // 15 saniye

    // 🔧 Event listeners
    hubConnection.on("NewLoginAttempt", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final data = arguments[0] as Map<String, dynamic>;
        _showApprovalDialog(context, data, onLogout);
      }
    });

    // 🔧 Bağlantı durumu dinleyicileri
    hubConnection.onclose(({error}) {
      print("❌ SignalR Bağlantısı Kapandı: $error");
      _isInitialized = false;
    });

    hubConnection.onreconnecting(({error}) {
      print("🔄 SignalR Yeniden Bağlanıyor...");
    });

    hubConnection.onreconnected(({connectionId}) {
      print("✅ SignalR Yeniden Bağlandı: $connectionId");
      // Yeniden register ol
      _registerUser(userId);
    });

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
      await hubConnection.invoke("RegisterUser", args: [userId.toString()]);
      print("✅ User Registered: $userId");
    } catch (e) {
      print("❌ RegisterUser Error: $e");
    }
  }

  // 🔧 Bağlantıyı düzgün kapat
  Future<void> dispose() async {
    if (_isInitialized) {
      try {
        await hubConnection.stop();
        _isInitialized = false;
        print("🛑 SignalR Disconnected");
      } catch (e) {
        print("❌ Dispose Error: $e");
      }
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

              Navigator.of(ctx).pop();

              bool result = await ApiService.approveDeviceLogin(
                  authProvider.currentCustomer!.cusId,
                  data['NewDeviceAndroidId'],
                  true);

              if (result) {
                onLogout();
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
