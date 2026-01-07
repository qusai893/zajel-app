import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';

import 'package:zajel/models/customer_balance_model.dart';
import 'package:zajel/models/transfer_model.dart';
import 'package:zajel/screens/beneficiaries_screen.dart';
import 'package:zajel/services/api_service.dart';
import 'package:zajel/services/connectivity_service.dart';
import 'package:zajel/services/signalr_service.dart';
import 'package:zajel/services/biometric_auth_service.dart';

import 'appColors.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transfers_screen.dart';
import 'screens/account_screen.dart';
import 'providers/auth_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await dotenv.load(fileName: ".env");

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint("Global Error: ${details.exception}");
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Asyncron Error: $error");
    return true;
  };
  runApp(TransferApp());
}

class TransferApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'زاجل للحوالات',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Cairo',
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
        ),
        home: SplashScreen(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: const Locale('ar'),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final BiometricAuthService _biometricService = BiometricAuthService();

  bool _isAuthInProgress = false;
  CustomerBalance? _currentBalance;
  bool _isLoadingAll = false;
  List<TransferModel> _sentTransfers = [];
  List<TransferModel> _receivedTransfers = [];

  @override
  void initState() {
    super.initState();
    ConnectivityService.observeNetwork(context);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSignalRConnection();
      _checkSecurityAndLoadData();
    });
  }

  @override
  void dispose() {
    SignalRService().dispose(); // ✅ Bağlantıyı temizle
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Uygulama arka plana geçtiğinde (veya kapandığında) oturumu kilitle
    if (state == AppLifecycleState.paused) {
      debugPrint("📱 App Playing at Background, Locking...");
      authProvider.setSessionVerified(false);
    }

    // Uygulama tekrar öne geldiğinde auth tetikle
    if (state == AppLifecycleState.resumed && !authProvider.isSessionVerified) {
      debugPrint("📱 Coming Back To Interface, Requesting Auth...");
      _triggerAuth();
    }
  }

  void _checkSecurityAndLoadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isSessionVerified) {
      _triggerAuth();
    } else {
      _refreshAllData();
    }
  }

  Future<void> _triggerAuth() async {
    if (_isAuthInProgress) return;

    setState(() => _isAuthInProgress = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      bool isAuthenticated = await _biometricService.authenticate();
      if (mounted) {
        if (isAuthenticated) {
          authProvider.setSessionVerified(true);
          _refreshAllData();
        } else {
          authProvider.setSessionVerified(false);
        }
      }
    } finally {
      if (mounted) setState(() => _isAuthInProgress = false);
    }
  }

  void _cancelOngoingAuth() {
    setState(() => _isAuthInProgress = false);
  }

  Future<void> _refreshAllData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isSessionVerified ||
        authProvider.currentCustomer == null ||
        _isLoadingAll) return;

    setState(() => _isLoadingAll = true);
    try {
      final userId = authProvider.currentCustomer!.cusId;
      await Future.wait([_loadBalance(userId), _loadTransfers()]);
    } finally {
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _loadBalance(int userId) async {
    try {
      final balance = await ApiService.getCustomerBalance(userId);
      if (mounted && balance != null) {
        setState(() => _currentBalance = balance);
        Provider.of<AuthProvider>(context, listen: false).updateCustomerBalance(
            balance.balanceSyr.toDouble(), balance.balanceDollar.toDouble());
      }
    } catch (e) {
      debugPrint("Bakiye hatası: $e");
    }
  }

  Future<void> _loadTransfers() async {
    try {
      final sentRes = await ApiService.getSentTransfers();
      final receivedRes = await ApiService.getReceivedTransfers();
      if (!mounted) return;
      setState(() {
        if (receivedRes['success'] == true) {
          _receivedTransfers = (receivedRes['transfers'] as List)
              .map((i) => TransferModel.fromJson(
                  Map<String, dynamic>.from(i), true, TransferType.received))
              .toList();
        }
        if (sentRes['success'] == true) {
          _sentTransfers = (sentRes['transfers'] as List)
              .map((i) => TransferModel.fromJson(
                  Map<String, dynamic>.from(i), false, TransferType.sent))
              .toList();
        }
      });
    } catch (e) {
      debugPrint("Transfer hatası: $e");
    }
  }

  void _initSignalRConnection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentCustomer != null) {
      SignalRService().initSignalR(
          authProvider.currentCustomer!.cusId, context, _performLogout);
    }
  }

  void _performLogout() async {
    await ApiService.logout();
    if (mounted)
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SplashScreen()),
          (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLocked = !authProvider.isSessionVerified;
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => false,
      child: Stack(
        children: [
          Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                DashboardScreen(
                    currentBalance: _currentBalance,
                    sentTransfers: _sentTransfers,
                    receivedTransfers: _receivedTransfers,
                    isLoading: _isLoadingAll,
                    onRefresh: _refreshAllData),
                TransfersScreen(),
                BeneficiariesScreen(isSelectionMode: false),
                AccountScreen(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_rounded), label: 'الرئيسية'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.swap_horizontal_circle_outlined),
                    label: 'حوالات'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.people_alt_outlined), label: 'المستفيدين'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.account_circle_outlined), label: 'حسابي'),
              ],
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() {
                _selectedIndex = i;
                if (i == 0) _refreshAllData();
              }),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          if (isLocked)
            Material(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      AppColors.background
                    ],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primary.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5)
                              ],
                            ),
                            child: Icon(
                              _isAuthInProgress
                                  ? Icons.fingerprint_rounded
                                  : Icons.lock_person_rounded,
                              size: size.width * 0.15,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 40),
                          const Text('زاجل للحوالات المالية',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                          const Text(
                              'يرجى تأكيد هويتك للوصول إلى بياناتك المالية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                          const SizedBox(height: 50),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isAuthInProgress ? null : _triggerAuth,
                              icon: _isAuthInProgress
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.lock_open_rounded),
                              label: Text(
                                  _isAuthInProgress
                                      ? 'جاري التحقق...'
                                      : 'فتح التطبيق الآن',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          if (_isAuthInProgress) ...[
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: _cancelOngoingAuth,
                              child: const Text("إلغاء المحاولة",
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          const Spacer(),
                          const Opacity(
                            opacity: 0.5,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('حماية مشفرة 256-bit',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
