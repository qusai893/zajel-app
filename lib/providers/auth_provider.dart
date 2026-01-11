import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zajel/models/transfer_model.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../models/device_auth_model.dart';

class AuthProvider with ChangeNotifier {
  // State variables
  Customer? _currentCustomer;
  String? _token;
  int _totalTransfers = 0;
  int _totalContacts = 0;
  DateTime? _accountCreationDate;
  List<TransferModel> _recentTransfers = [];
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String _errorMessage = '';
  final transferSent = TransferType.sent;
  int _totalSentTransfers = 0;

  // --- KRİTİK: Gönderici Bilgileri Cache Mekanizması ---
  Map<String, dynamic>? _senderInfo;
  Map<String, dynamic>? get senderInfo => _senderInfo;

  // Gönderici bilgisini set eder ve yerel hafızaya kaydeder (Hız için)
  void setSenderInfo(Map<String, dynamic> info) {
    _senderInfo = info;
    _saveSenderInfoToStorage(info); // Hafızaya yaz
    notifyListeners();
  }

  Future<void> _saveSenderInfoToStorage(Map<String, dynamic> info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_sender_info', json.encode(info));
    } catch (e) {
      print("❌ Sender Info Cache Error: $e");
    }
  }

  // Getters
  Customer? get currentCustomer => _currentCustomer;
  String? get token => _token;
  int get totalTransfers => _totalTransfers;
  int get totalSentTransfers => _totalSentTransfers;
  int get totalContacts => _totalContacts;
  DateTime? get accountCreationDate => _accountCreationDate;
  List<TransferModel> get recentTransfers => _recentTransfers;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String get errorMessage => _errorMessage;

  bool _isSessionVerified = false;
  bool get isSessionVerified => _isSessionVerified;

  // Hesap süresi hesaplama
  String get accountDuration {
    if (_accountCreationDate == null) return 'جديد';
    final now = DateTime.now();
    final difference = now.difference(_accountCreationDate!);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    if (years > 0) return '$years سنة';
    if (months > 0) return '$months شهر';
    return 'جديد';
  }

  void setSessionVerified(bool value) {
    _isSessionVerified = value;
    notifyListeners();
  }

  // Constructor
  AuthProvider() {
    _initialize();
  }

  // Initialize provider
  Future<void> _initialize() async {
    await _loadCustomerFromStorage();
    if (_isAuthenticated) {
      await _loadAccountStats();
      // Arka planda bilgileri tazele
      refreshUserInfo();
    }
  }

  void setToken(String token) {
    _token = token;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString('token', token));
    notifyListeners();
  }

  // Dışarıdan Müşteri Verisi Atamak için
  void setCustomer(Map<String, dynamic> customerData) {
    try {
      _currentCustomer = Customer.fromJson(customerData);
      print("✅ Kullanıcı set edildi: ${_currentCustomer?.cusName}");
      _saveCustomerToStorage();
      notifyListeners();
    } catch (e) {
      print("❌ AuthProvider setCustomer Error: $e");
    }
  }

  // ⭐ KRİTİK: Bakiye güncelleme - timestamp ile cache invalidation
  void updateCustomerBalance(double syr, double dollar) {
    if (_currentCustomer == null) return;

    if (_currentCustomer!.cusBalanceSyr == syr &&
        _currentCustomer!.cusBalanceDollar == dollar) {
      print('ℹ️ Balance did not change, Update Skipped');
      return;
    }

    _currentCustomer = Customer(
      cusId: _currentCustomer!.cusId,
      cusName: _currentCustomer!.cusName,
      cusFatherName: _currentCustomer!.cusFatherName,
      cusLastName: _currentCustomer!.cusLastName,
      regName: _currentCustomer!.regName,
      clientId: _currentCustomer!.clientId,
      cusBalanceSyr: syr,
      cusBalanceDollar: dollar,
    );

    _saveCustomerToStorage();
    notifyListeners();

    print('✅ BAKİYE GÜNCELLENDİ: Dollar: $dollar USD, Syrian: $syr SYP');
  }

  // Load customer data from SharedPreferences
  Future<void> _loadCustomerFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      final token = prefs.getString('token');
      final cachedSender = prefs.getString('cached_sender_info');

      if (userString == null || token == null) {
        _isAuthenticated = false;
        return;
      }

      // Hız için: Daha önce kaydedilmiş gönderici bilgisini RAM'e al
      if (cachedSender != null) {
        _senderInfo = json.decode(cachedSender);
      }

      final userData = json.decode(userString);
      _currentCustomer = Customer(
        cusId: userData['cusId'] ?? 0,
        cusName: userData['cusName'] ?? '',
        // Key uyuşmazlığına karşı çift kontrol
        cusLastName: userData['cusLastName'] ?? userData['CusLastName'] ?? '',
        regName: userData['cityName'] ?? userData['regName'] ?? '',
        cusBalanceSyr: (userData['cusBalanceSyr'] ?? 0).toDouble(),
        cusBalanceDollar: (userData['cusBalanceDollar'] ?? 0).toDouble(),
        clientId: userData['clientId'] ?? '',
      );

      _token = token;
      final firstLogin = prefs.getString('firstLoginDate');
      _accountCreationDate =
          firstLogin != null ? DateTime.parse(firstLogin) : DateTime.now();

      if (firstLogin == null) {
        await prefs.setString(
            'firstLoginDate', _accountCreationDate!.toIso8601String());
      }

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      print('❌ Storage load error: $e');
      _errorMessage = 'فشل تحميل بيانات المستخدم';
    }
  }

  // Save with timestamp
  Future<void> _saveCustomerToStorage() async {
    if (_currentCustomer == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'cusId': _currentCustomer!.cusId,
        'cusName': _currentCustomer!.cusName,
        'cusLastName': _currentCustomer!.cusLastName,
        'cusBalanceSyr': _currentCustomer!.cusBalanceSyr,
        'cusBalanceDollar': _currentCustomer!.cusBalanceDollar,
        'clientId': _currentCustomer!.clientId,
        'cityName': _currentCustomer!.regName,
      };

      await prefs.setString('user', json.encode(userData));
      await prefs.setString(
          'last_balance_update', DateTime.now().toIso8601String());
    } catch (e) {
      print('❌ Storage save error: $e');
    }
  }

  // Login method
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();
    try {
      final isConnected = await ApiService.testConnection();
      if (!isConnected) {
        _setError('تعذر الاتصال بالخادم');
        return false;
      }

      final response = await ApiService.login(username, password);
      final customerData = response['customer'];
      _token = response['token'];

      if (customerData != null) {
        _currentCustomer = Customer.fromJson(customerData);
        _isAuthenticated = true;
        _isSessionVerified = false;
        await _saveCustomerToStorage();
        // Login sonrası gönderici bilgilerini çek ve cachele
        await refreshUserInfo();
        await _loadAccountStats();
        return true;
      } else {
        _setError('بيانات الحساب غير مكتملة');
        return false;
      }
    } catch (e) {
      String message = e.toString();
      if (message.startsWith("Exception: ")) message = message.substring(11);
      _setError(message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadAccountStats() async {
    print('📊 [LOAD ACCOUNT STATS] Starting...');
    try {
      final sentTransfers = await ApiService.getSentTransfers();
      final sentList = (sentTransfers['transfers'] as List?) ?? [];

      final receivedTransfers = await ApiService.getReceivedTransfers();
      final receivedList = (receivedTransfers['transfers'] as List?) ?? [];
      _totalSentTransfers = sentList.length;
      _totalTransfers = sentList.length + receivedList.length;

      if (sentList.isNotEmpty) {
        final uniqueReceivers = sentList
            .map((t) => t is Map ? (t['receiverName']?.toString() ?? '') : '')
            .where((name) => name.isNotEmpty)
            .toSet();
        _totalContacts = uniqueReceivers.length;
      } else {
        _totalContacts = 0;
      }

      try {
        final allTransfers = await ApiService.getAllTransfers();
        _recentTransfers = allTransfers.take(3).toList();
      } catch (e) {
        _recentTransfers = [];
      }
      notifyListeners();
    } catch (e) {
      print('❌ [LOAD ACCOUNT STATS] Error: $e');
    }
  }

  // ⭐ Refresh - Tüm verileri tazele
  Future<void> refreshAccountData() async {
    try {
      print('🔄 RefreshAccountData Started');
      await _loadAccountStats();
      await refreshUserInfo();
      print('✅ RefreshAccountData Completed');
    } catch (e) {
      print('❌ Refresh error: $e');
    }
  }

  // ⭐ Sadece isim ve username güncelle (Cache dahil)
  Future<void> refreshUserInfo() async {
    try {
      final senderInfoMap = await ApiService.getSenderInfo();
      if (senderInfoMap != null) {
        // Makbuz ekranı için cache'e yaz
        setSenderInfo(senderInfoMap);

        if (_currentCustomer != null) {
          _currentCustomer = Customer(
            cusId: _currentCustomer!.cusId,
            regName: senderInfoMap['cityName'] ?? _currentCustomer!.regName,
            cusName: senderInfoMap['cuS_NAME'] ??
                senderInfoMap['cusName'] ??
                _currentCustomer!.cusName,
            cusFatherName: senderInfoMap['cusFatherName'] ??
                _currentCustomer!.cusFatherName,
            cusLastName: senderInfoMap['cusLastName'] ??
                senderInfoMap['CusLastName'] ??
                _currentCustomer!.cusLastName,
            cusBalanceSyr: _currentCustomer!.cusBalanceSyr,
            cusBalanceDollar: _currentCustomer!.cusBalanceDollar,
            clientId: _currentCustomer!.clientId,
          );
          await _saveCustomerToStorage();
          notifyListeners();
          print('👤 Kullanıcı bilgileri ve SenderInfo güncellendi');
        }
      }
    } catch (e) {
      print('❌ User info refresh error: $e');
    }
  }

  // ⭐ DEPRECATED
  @Deprecated('Use MainScreen._loadBalance instead')
  void updateBalance({
    required String currency,
    required int amount,
    TransferModel? transfer,
  }) {
    if (_currentCustomer == null) return;
    final customer = _currentCustomer!;
    _currentCustomer = Customer(
      cusId: customer.cusId,
      cusName: customer.cusName,
      regName: customer.regName,
      cusLastName: customer.cusLastName,
      cusBalanceSyr: currency == 'SYP'
          ? customer.cusBalanceSyr - amount
          : customer.cusBalanceSyr,
      cusBalanceDollar: currency == 'USD'
          ? customer.cusBalanceDollar - amount
          : customer.cusBalanceDollar,
      clientId: customer.clientId,
    );
    _saveCustomerToStorage();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();
    } catch (e) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _currentCustomer = null;
    _senderInfo = null;
    _isAuthenticated = false;
    _isSessionVerified = false;
    _totalTransfers = 0;
    _totalContacts = 0;
    _recentTransfers = [];
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> checkSession() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (isLoggedIn) {
      await _loadCustomerFromStorage();
      await _loadAccountStats();
    } else {
      _isAuthenticated = false;
      _currentCustomer = null;
    }
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  Future<bool> changePassword(
      {required String oldPassword, required String newPassword}) async {
    _setLoading(true);
    _clearError();
    try {
      if (_currentCustomer == null)
        throw Exception('لم يتم العثور على بيانات المستخدم');
      final response = await ApiService.changePassword(
        customerId: _currentCustomer!.cusId,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      if (response['success'] == true) {
        _clearUserData();
        return true;
      } else {
        _setError(response['message'] ?? 'فشل تغيير كلمة المرور');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _clearUserData() {
    _currentCustomer = null;
    _senderInfo = null;
    _isAuthenticated = false;
    _isSessionVerified = false;
    _totalTransfers = 0;
    _totalContacts = 0;
    _recentTransfers = [];
    notifyListeners();
  }

  Future<void> _handleSuccessfulLogin(DeviceAuthResponse response) async {
    _currentCustomer = Customer.fromJson(response.customer!);
    _isAuthenticated = true;
    await ApiService.saveAuthData(response.token!, response.customer!);
    notifyListeners();
  }
}
