import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // 1. EKLENEN IMPORT
import '../services/device_auth_service.dart';
import '../providers/auth_provider.dart';
import '../main.dart';

class QrLoginScreen extends StatefulWidget {
  final String androidId;

  const QrLoginScreen({Key? key, required this.androidId}) : super(key: key);

  @override
  _QrLoginScreenState createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen>
    with WidgetsBindingObserver {
  final DeviceAuthService _authService = DeviceAuthService();

  // İşlem durumu ve son okunan kod
  bool isProcessing = false;
  String? lastScannedCode;

  // Kamera kontrolcüsü
  final MobileScannerController controller = MobileScannerController(
      // Otomatik başlatma ayarları vs. buraya eklenebilir
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Hemen başlatmak yerine 500ms bekle (Kamera açılış performansı için)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        controller.start();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  // App Lifecycle yönetimi
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        controller.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();

    // Galeriyi aç
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    if (isProcessing) return;

    try {
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        _onQrDetected(capture);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("لم يتم العثور على رمز QR في الصورة"), // QR bulunamadı
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Galery Scaning Error: $e");
    }
  }

  // Kamera QR'ı görünce burası çalışır (Galeriden seçilince de burası çalışacak)
  void _onQrDetected(BarcodeCapture capture) {
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;

    if (code != null) {
      // Kodu hafızaya alıyoruz ki "Tekrar Dene" dediğimizde kullanabilelim
      lastScannedCode = code;
      _performLogin(code);
    }
  }

  Future<void> _performLogin(String qrCode) async {
    setState(() => isProcessing = true);

    try {
      final result = await _authService.qrLogin(widget.androidId, qrCode);

      if (!mounted) return;

      if (result != null && result.success) {
        // --- BAŞARILI GİRİŞ ---
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (result.token != null) authProvider.setToken(result.token!);
        if (result.customer != null) authProvider.setCustomer(result.customer!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.message), backgroundColor: Colors.green),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else if (result != null && result.message == 'WAIT_APPROVAL') {
        setState(() => isProcessing = false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("مطلوب موافقة", textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  "لقد أرسلنا طلباً إلى جهازك الآخر.\nيرجى فتح التطبيق هناك والموافقة.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (lastScannedCode != null) _performLogin(lastScannedCode!);
                },
                child: const Text("لقد وافقت، متابعة"),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?.message ?? "رمز QR غير صالح"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => isProcessing = false);
      }
    } catch (e) {
      setState(() => isProcessing = false);
      debugPrint("QR Login Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ربط الجهاز",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // 3. YENİ EKLENEN İKON BUTON (SAĞ ÜST KÖŞE)
        actions: [
          IconButton(
            icon: const Icon(Icons.image), // Galeri ikonu
            tooltip: "اختر من المعرض", // "Galeriden seç"
            onPressed: _scanFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Kamera Katmanı
          MobileScanner(
            controller: controller,
            onDetect: _onQrDetected,
          ),

          // 2. QR Çerçevesi
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 4),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          // 3. İşlem Yapılıyor Katmanı (Overlay)
          if (isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.blueAccent),
                    const SizedBox(height: 25),
                    const Text(
                      "جاري ربط الجهاز...",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "يرجى الانتظار قليلاً",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Bilgilendirme Alt Panel
          if (!isProcessing)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  "يرجى توجيه الكاميرا نحو رمز QR الخاص بك\nأو اختر صورة من المعرض",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
