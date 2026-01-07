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

  // Getters
  Customer? get currentCustomer => _currentCustomer;
  String? get token => _token;
  int get totalTransfers => _totalTransfers;
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
    await _loadAccountStats();
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
      print("❌ AuthProvider setCustomer Hatası: $e");
    }
  }

  // ⭐ KRİTİK: Bakiye güncelleme - timestamp ile cache invalidation
  void updateCustomerBalance(double syr, double dollar) {
    if (_currentCustomer == null) return;

    // Veri değişmemişse güncelleme yapma
    if (_currentCustomer!.cusBalanceSyr == syr &&
        _currentCustomer!.cusBalanceDollar == dollar) {
      print('ℹ️ Balance did not change,Update Skipped');
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

    print('✅ BAKİYE GÜNCELLENDİ:');
    print('   💵 Dollar: $dollar USD');
    print('   💴 Syrian: $syr SYP');
  }

  // QR ile Giriş
  Future<bool> loginWithQr(String androidId, String qrSerial) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.qrLogin(androidId, qrSerial);
      final response = DeviceAuthResponse.fromJson(data);

      if (response.success) {
        await _handleSuccessfulLogin(response);
        return true;
      } else {
        _errorMessage = response.message;
        return false;
      }
    } catch (e) {
      _errorMessage = "خطأ في الاتصال";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load customer data from SharedPreferences
  Future<void> _loadCustomerFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      final token = prefs.getString('token');

      if (userString == null || token == null) {
        _isAuthenticated = false;
        return;
      }

      final userData = json.decode(userString);
      _currentCustomer = Customer(
        cusId: userData['cusId'] ?? 0,
        cusName: userData['cusName'] ?? '',
        cusLastName: userData['CusLastName'] ?? '',
        regName: userData['cityName'],
        cusBalanceSyr: (userData['cusBalanceSyr'] ?? 0).toDouble(),
        cusBalanceDollar: (userData['cusBalanceDollar'] ?? 0).toDouble(),
        clientId: userData['clientId'] ?? '',
      );

      final firstLogin = prefs.getString('firstLoginDate');
      _accountCreationDate =
          firstLogin != null ? DateTime.parse(firstLogin) : DateTime.now();

      if (firstLogin == null) {
        await prefs.setString(
            'firstLoginDate', _accountCreationDate!.toIso8601String());
      }

      _isAuthenticated = true;

      print('📦 Storage\'dan yüklenen bakiye:');
      print('   💵 ${_currentCustomer!.cusBalanceDollar} USD');
      print('   💴 ${_currentCustomer!.cusBalanceSyr} SYP');

      notifyListeners();
    } catch (e) {
      print('❌ Storage load error: $e');
      _errorMessage = 'فشل تحميل بيانات المستخدم';
    }
  }

  // ⭐ Save with timestamp
  Future<void> _saveCustomerToStorage() async {
    if (_currentCustomer == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'cusId': _currentCustomer!.cusId,
        'cusName': _currentCustomer!.cusName,
        'CusLastName': _currentCustomer!.cusLastName,
        'cusBalanceSyr': _currentCustomer!.cusBalanceSyr,
        'cusBalanceDollar': _currentCustomer!.cusBalanceDollar,
        'clientId': _currentCustomer!.clientId,
        'cityName': _currentCustomer!.regName,
      };

      await prefs.setString('user', json.encode(userData));
      await prefs.setString(
          'last_balance_update', DateTime.now().toIso8601String());

      print('💾 Saved To Storage (${DateTime.now().toIso8601String()})');
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

      if (customerData != null) {
        _currentCustomer = Customer.fromJson(customerData);
        _isAuthenticated = true;
        _isSessionVerified = false;
        await _saveCustomerToStorage();
        await _loadAccountStats();
        return true;
      } else {
        _setError('بيانات الحساب غير مكتملة');
        return false;
      }
    } catch (e) {
      String message = e.toString();
      if (message.startsWith("Exception: ")) {
        message = message.substring(11);
      }
      if (message.contains("ClientException") ||
          message.contains("SocketException")) {
        message = 'لا يوجد اتصال بالإنترنت';
      }
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

      _totalTransfers = sentList.length + receivedList.length;

      if (sentList.isNotEmpty) {
        final uniqueReceivers = sentList
            .map((t) {
              if (t is Map) {
                return t['receiverName']?.toString() ?? '';
              }
              return '';
            })
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
        print('❌ getAllTransfers Error: $e');
        _recentTransfers = [];
      }

      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ [LOAD ACCOUNT STATS] Error: $e');
      _totalTransfers = 0;
      _totalContacts = 0;
      _recentTransfers = [];
      notifyListeners();
    }
  }

  // ⭐ Refresh - Bakiye API'den çekilmeli
  Future<void> refreshAccountData() async {
    try {
      print('🔄 RefreshAccountData Started');

      // İstatistikleri yükle
      await _loadAccountStats();

      // Profil bilgilerini yükle (sadece isim/username)
      await refreshUserInfo();

      print('✅ RefreshAccountData Completed');
    } catch (e) {
      print('❌ Refresh error: $e');
    }
  }

  // ⭐ Sadece isim ve username güncelle
  Future<void> refreshUserInfo() async {
    try {
      final senderInfo = await ApiService.getSenderInfo();

      if (senderInfo != null && _currentCustomer != null) {
        // Sadece isim bilgilerini güncelle, bakiyeye DOKUNMA
        _currentCustomer = Customer(
          cusId: _currentCustomer!.cusId,
          regName: _currentCustomer!.regName,
          cusName: senderInfo['cus_NAME'] ?? _currentCustomer!.cusName,
          cusFatherName:
              senderInfo['cusFatherName'] ?? _currentCustomer!.cusFatherName,
          cusLastName:
              senderInfo['CusLastName'] ?? _currentCustomer!.cusLastName,
          // BAKİYEYİ KORU
          cusBalanceSyr: _currentCustomer!.cusBalanceSyr,
          cusBalanceDollar: _currentCustomer!.cusBalanceDollar,
          clientId: _currentCustomer!.clientId,
        );

        await _saveCustomerToStorage();
        notifyListeners();

        print('👤 Kullanıcı bilgileri güncellendi (bakiye korundu)');
      }
    } catch (e) {
      print('❌ User info refresh error: $e');
    }
  }

  // ⭐ DEPRECATED - MainScreen'den çağrılmamalı
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

    print('⚠️ DEPRECATED updateBalance kullanıldı: -$amount $currency');
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();
    } catch (e) {
      print('Logout API error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _currentCustomer = null;
    _isAuthenticated = false;
    _isSessionVerified = false;
    _totalTransfers = 0;
    _totalContacts = 0;
    _recentTransfers = [];
    _errorMessage = '';

    notifyListeners();

    print('✅ Logout: Tüm state temizlendi');
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

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (_currentCustomer == null) {
        throw Exception('لم يتم العثور على بيانات المستخدم');
      }

      final response = await ApiService.changePassword(
        customerId: _currentCustomer!.cusId,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (response['success'] == true) {
        _clearUserData();
        return true;
      } else {
        final errorMessage = response['message'] ?? 'فشل تغيير كلمة المرور';
        _setError(errorMessage);
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

  void _clearUserData() {
    _currentCustomer = null;
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
