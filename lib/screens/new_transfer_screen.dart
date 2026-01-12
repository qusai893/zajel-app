import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zajel/appColors.dart';
import 'package:zajel/main.dart';
import 'package:zajel/models/beneficiary_model.dart';
import 'package:zajel/screens/beneficiaries_screen.dart';
import 'package:zajel/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:zajel/services/beneficiary_service.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
// Biyometrik servisinizin yolunu projenize göre kontrol edin
// import 'package:zajel/services/auth_service.dart';

class NewTransferScreen extends StatefulWidget {
  final BeneficiaryModel? initialBeneficiary;

  NewTransferScreen({this.initialBeneficiary});
  @override
  _NewTransferScreenState createState() => _NewTransferScreenState();
}

// WidgetsBindingObserver ekleyerek uygulama yaşam döngüsünü (arka plan/ön plan) izliyoruz
class _NewTransferScreenState extends State<NewTransferScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  Timer? _debounce;
  Timer? _statsTimer;

  // Form Değişkenleri
  int _amount = 0;
  String _currency = 'USD';
  int _fee = 0;
  int _totalAmount = 0;

  // Limit ve İstatistik Değişkenleri
  num _minLimit = 0;
  num _maxLimit = 0;
  String? _limitError;
  int _remainingTransfersCount = 0;
  int _maxAllowedTransfers = 0;
  String _timeRemainingStr = "00:00:00";
  Duration _remainingDuration = Duration.zero;
  Map<String, dynamic>? _cachedSettings;
  List<dynamic> _cities = [];
  // Controller'lar
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _receiverPhoneController =
      TextEditingController();
  final TextEditingController _receiverMobilePhoneController =
      TextEditingController();
  final TextEditingController _transferReasonController =
      TextEditingController();
  final TextEditingController _senderNotesController = TextEditingController();

  int _selectedCityId = 0;
  String _selectedCityName = '';
  String _notificationNumber = '---';

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isCalculating = false;
  bool _isExistingReceiver = false;
  bool _checkingReceiver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Lifecycle izleyiciyi başlat
    _firstNameController.addListener(_onNameChanged);
    _fatherNameController.addListener(_onNameChanged);
    _lastNameController.addListener(_onNameChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      if (widget.initialBeneficiary != null) {
        _fillFormWithBeneficiary(widget.initialBeneficiary!);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Lifecycle izleyiciyi kaldır
    _debounce?.cancel();
    _statsTimer?.cancel();
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _lastNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverMobilePhoneController.dispose();
    _transferReasonController.dispose();
    _senderNotesController.dispose();
    super.dispose();
  }

  // --- BİYOMETRİK GÜVENLİK KONTROLÜ (UYGULAMAYA GERİ DÖNÜLDÜĞÜNDE) ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authenticateUser(); // Uygulama ön plana geldiğinde şifre/parmak izi iste
    }
  }

  Future<void> _authenticateUser() async {
    // Burada projenizdeki mevcut biyometrik doğrulama metodunu çağırın.
    // Örnek: final authenticated = await AuthService.authenticate();
    // Eğer başarısız olursa kullanıcıyı login ekranına atabilir veya uygulamayı kapatabilirsiniz.
    debugPrint("Biyometrik doğrulama tetiklendi (App Resumed)");
  }

  // --- ÇIKIŞ ONAY DİYALOĞU ---
  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تنبيه',
            textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        content: Text('هل أنت متأكد من رغبتك في إلغاء عملية التحويل والخروج؟',
            textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('لا',
                style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('نعم، خروج',
                style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getCities().catchError((e) => []),
        ApiService.generateNotificationNumber().catchError((e) => "---"),
        ApiService.getDailyStats().catchError((e) => null),
        ApiService.getTransferSettings().catchError((e) => null),
      ]);

      if (!mounted) return;
      setState(() {
        _cities = results[0] as List<dynamic>? ?? [];
        _notificationNumber = results[1] as String? ?? "---";
        if (results[2] != null) {
          final stats = results[2] as Map<String, dynamic>;
          _remainingTransfersCount = stats['remainingTransfers'] ?? 0;
          _maxAllowedTransfers = stats['maxAllowedTransfers'] ?? 0;
          _startCountdown(stats['timeRemaining']);
        }
        if (results[3] != null) {
          _cachedSettings = results[3] as Map<String, dynamic>;
          _updateLimits(_cachedSettings!);
        }
      });
    } catch (e) {
      _showError("حدث خطأ أثناء تحميل البيانات، يرجى التحقق من الاتصال");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateLimits(Map<String, dynamic> settings) {
    setState(() {
      if (_currency == 'USD') {
        _minLimit =
            settings['minDollarAmount'] ?? settings['MinDollarAmount'] ?? 0;
        _maxLimit =
            settings['maxDollarAmount'] ?? settings['MaxDollarAmount'] ?? 0;
      } else {
        _minLimit = settings['minSyrAmount'] ?? settings['MinSyrAmount'] ?? 0;
        _maxLimit = settings['maxSyrAmount'] ?? settings['MaxSyrAmount'] ?? 0;
      }
    });
  }

  void _startCountdown(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return;
    try {
      List<String> parts = timeStr.split(':');
      if (parts.length == 3) {
        _remainingDuration = Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
        _statsTimer?.cancel();
        _statsTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (_remainingDuration.inSeconds <= 0) {
            timer.cancel();
            _initializeData();
          } else {
            if (mounted) {
              setState(() {
                _remainingDuration -= Duration(seconds: 1);
                _timeRemainingStr = _formatDuration(_remainingDuration);
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Timer Error: $e");
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  void _onAmountChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      int? val = int.tryParse(value);
      if (val != null) {
        setState(() {
          _amount = val;
          if (_amount > 0 && _amount < _minLimit) {
            _limitError = "القيمة أقل من الحد\n المسموح ($_minLimit)";
          } else if (_amount > _maxLimit) {
            _limitError = "القيمة أكبر من الحد \nالمسموح ($_maxLimit)";
          } else {
            _limitError = null;
          }
        });
        // Sadece hata yoksa ve miktar 0'dan büyükse hesapla
        if (_limitError == null && _amount > 0) {
          await _calculateTransferFee();
        }
      } else {
        setState(() {
          _amount = 0;
          _fee = 0;
          _limitError = null;
        });
      }
    });
  }

  Future<void> _calculateTransferFee() async {
    setState(() => _isCalculating = true);
    try {
      final feeData = await ApiService.calculateFee(_amount, _currency);
      setState(() {
        _fee = (feeData['fee'] as num?)?.toInt() ?? 0;
        _totalAmount =
            (feeData['totalAmount'] as num?)?.toInt() ?? (_amount + _fee);
      });
    } catch (e) {
      debugPrint("Fee Calculation Error: $e");
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  void _onNameChanged() {
    if (_firstNameController.text.trim().length > 2 &&
        _fatherNameController.text.trim().length > 2 &&
        _lastNameController.text.trim().length > 2) {
      _checkReceiver();
    }
  }

  Future<void> _checkReceiver() async {
    setState(() => _checkingReceiver = true);
    try {
      final exists = await ApiService.checkReceiverExists(
          _firstNameController.text.trim(),
          _fatherNameController.text.trim(),
          _lastNameController.text.trim());
      setState(() => _isExistingReceiver = exists);
    } catch (e) {
      debugPrint("Check Receiver Error: $e");
    } finally {
      setState(() => _checkingReceiver = false);
    }
  }

  void _fillFormWithBeneficiary(BeneficiaryModel person) {
    setState(() {
      _firstNameController.text = person.firstName;
      _fatherNameController.text = person.fatherName;
      _lastNameController.text = person.lastName;
      _receiverPhoneController.text = person.phone;
      _receiverMobilePhoneController.text = person.mobile;
      _selectedCityId = person.cityId;
      _selectedCityName = person.cityName;
    });
    _checkReceiver();
  }

  // --- GÜVENLİ TRANSFER GÖNDERİMİ ---
  Future<void> _submitTransfer() async {
    if (_isSubmitting) return; // Çift gönderim engelleme

    // 1. Form Validasyonu
    if (!_formKey.currentState!.validate() || _limitError != null) {
      _showError('يرجى التأكد من جميع البيانات المدخلة');
      return;
    }

    // 2. Havale Sebebi Güvenlik Kontrolü (Minimum 5 karakter, sadece anlamlı metin)
    final reason = _transferReasonController.text.trim();
    final reasonRegex = RegExp(
        r'^[a-zA-Z\s\u0600-\u06FF]{5,100}$'); // Harfler ve boşluklar, 5-100 karakter
    if (!reasonRegex.hasMatch(reason)) {
      _showError('يرجى إدخال سبب تحويل واضح (أحرف فقط وبدون رموز)');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final customer = authProvider.currentCustomer;

      // Bakiye kontrolü
      double balance = _currency == 'USD'
          ? (customer?.cusBalanceDollar.toDouble() ?? 0)
          : (customer?.cusBalanceSyr.toDouble() ?? 0);

      if ((_amount + _fee) > balance) {
        _showError('عفواً، رصيدك غير كافي لهذه العملية');
        setState(() => _isSubmitting = false);
        return;
      }

      // Verileri güvenli şekilde hazırla
      final transferData = {
        'amount': _amount,
        'currency': _currency,
        'totalAmount': _amount + _fee,
        'receiverName': _firstNameController.text.trim(),
        'receiverFatherName': _fatherNameController.text.trim(),
        'receiverLastName': _lastNameController.text.trim(),
        'receiverCityId': _selectedCityId,
        'receiverPhone': _receiverPhoneController.text.trim(),
        'receiverMobilePhone': _receiverMobilePhoneController.text.trim(),
        'transferReason': reason,
        'senderNotes': _senderNotesController.text.trim(),
      };

      final result = await ApiService.sendTransfer(transferData);

      if (result['success'] == true) {
        // Rehbere kaydet
        BeneficiaryService.saveBeneficiary(BeneficiaryModel(
          firstName: _firstNameController.text.trim(),
          fatherName: _fatherNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _receiverPhoneController.text.trim(),
          mobile: _receiverMobilePhoneController.text.trim(),
          cityId: _selectedCityId,
          cityName: _selectedCityName,
        ));

        await authProvider.refreshUserInfo();
        _showSuccess('✅ تم إرسال الحوالة بنجاح');

        if (mounted) {
          Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (c) => MainScreen()), (r) => false);
        }
      } else {
        _showError(result['message'] ?? 'خطأ في عملية الإرسال');
      }
    } catch (e) {
      _showError("حدث خطأ غير متوقع، يرجى المحاولة لاحقاً");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red));

  void _showSuccess(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg,
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final customer = authProvider.currentCustomer;
    final double syrBalance = customer?.cusBalanceSyr.toDouble() ?? 0.0;
    final double dollarBalance = customer?.cusBalanceDollar.toDouble() ?? 0.0;

    // PopScope ile çıkış kontrolü sağlanıyor
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading
            ? _buildLoadingState()
            : LayoutBuilder(
                builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 600;
                  return GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: CustomScrollView(
                      physics: BouncingScrollPhysics(),
                      slivers: [
                        _buildSliverAppBar(context),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 32, vertical: 10),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildDailyStatsHeader(),
                              SizedBox(height: 16),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildSenderCard(
                                        isMobile,
                                        "${customer?.cusName ?? ''} ${customer?.cusFatherName ?? ''} ${customer?.cusLastName ?? ''}",
                                        syrBalance,
                                        dollarBalance),
                                    SizedBox(height: 20),
                                    _buildAmountCard(isMobile),
                                    SizedBox(height: 20),
                                    _buildReceiverCard(isMobile),
                                    SizedBox(height: 20),
                                    _buildDestinationCard(isMobile),
                                    SizedBox(height: 30),
                                    _buildActionButtons(isMobile),
                                    SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  // --- WIDGET BİLEŞENLERİ ---

  Widget _buildTransferStatusWidget() {
    if (_remainingTransfersCount <= 0) {
      return Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 18),
          SizedBox(width: 4),
          Text("عفواً، استنفدت حدك اليومي",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.red,
                  fontFamily: 'Cairo')),
        ],
      );
    }
    if (_remainingTransfersCount <= 3) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange[700], size: 18),
          SizedBox(width: 4),
          Text("متبقي $_remainingTransfersCount تحويلات فقط",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange[800],
                  fontFamily: 'Cairo')),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
        SizedBox(width: 4),
        Text("$_remainingTransfersCount / $_maxAllowedTransfers",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
                fontFamily: 'Cairo')),
      ],
    );
  }

  Widget _buildDailyStatsHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("حالة حد التحويل اليومي",
                  style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontFamily: 'Cairo')),
              const SizedBox(height: 4),
              _buildTransferStatusWidget(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("يتصفر عداد الحوالات خلال",
                  style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontFamily: 'Cairo')),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(_timeRemainingStr,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange[800],
                          fontFamily: 'Cairo')),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSenderCard(bool isMobile, String name, double syr, double usd) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary),
                SizedBox(width: 10),
                Text('المحفظة والرصيد',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Spacer(),
                _buildNotificationBadge(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(children: [
                  Icon(Icons.person, size: 18, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Text('المرسل: ',
                      style: TextStyle(
                          fontFamily: 'Cairo', color: AppColors.secondary)),
                  Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold))),
                ]),
                Divider(height: 24),
                Row(children: [
                  Expanded(
                      child: _buildBalanceItem(
                          'USD', usd, Icons.attach_money, Colors.green)),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  Expanded(
                      child: _buildBalanceItem(
                          'SYP', syr, Icons.money, Colors.blue)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(_notificationNumber,
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary)),
    );
  }

  Widget _buildAmountCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المبلغ والعملة', style: _sectionTitleStyle()),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.left,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo'),
                    decoration: _inputDecoration(
                            hintText: '0', prefixIcon: Icons.money_rounded)
                        .copyWith(
                      errorText: _limitError,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    onChanged: _onAmountChanged,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'يرجى إدخال المبلغ';
                      int? val = int.tryParse(v);
                      if (val == null || val <= 0) return 'مبلغ غير صالح';
                      if (val < _minLimit) return 'الحد الأدنى هو $_minLimit';
                      if (val > _maxLimit) return 'الحد الأعلى هو $_maxLimit';
                      return null;
                    },
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: _inputDecoration(
                        hintText: '', prefixIcon: Icons.currency_exchange),
                    items: [
                      DropdownMenuItem(
                          value: 'USD',
                          child: Text('USD',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DropdownMenuItem(
                          value: 'SYP',
                          child: Text('ل.س',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _currency = val!;
                        if (_cachedSettings != null) {
                          _updateLimits(_cachedSettings!);
                          if (_amount > 0) _onAmountChanged(_amount.toString());
                        }
                      });
                    }),
              ),
            ],
          ),
          if (_fee > 0 || _isCalculating) _buildFeeDisplay(),
        ],
      ),
    );
  }

  Widget _buildFeeDisplay() {
    return Container(
      margin: EdgeInsets.only(top: 15),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('رسوم التحويل:',
              style:
                  TextStyle(fontFamily: 'Cairo', color: AppColors.secondary)),
          _isCalculating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text('${_fee.toStringAsFixed(0)} $_currency',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildReceiverCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('بيانات المستفيد', style: _sectionTitleStyle()),
              Spacer(),
              if (_checkingReceiver)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_isExistingReceiver)
                _buildExistingBadge(),
              _buildSavedContactsBtn(),
            ],
          ),
          SizedBox(height: 16),
          _buildNameFields(isMobile),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildModernTextField(
                      controller: _receiverPhoneController,
                      label: 'الهاتف',
                      icon: Icons.phone_outlined,
                      isPhone: true // Telefon formatı için true
                      )),
              SizedBox(width: 12),
              Expanded(
                  child: _buildModernTextField(
                      controller: _receiverMobilePhoneController,
                      label: 'الموبايل',
                      icon: Icons.smartphone_outlined,
                      isPhone: true // Telefon formatı için true
                      )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExistingBadge() {
    return Container(
      margin: EdgeInsets.only(left: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text('عميل سابق',
          style: TextStyle(
              fontSize: 10, color: Colors.green, fontFamily: 'Cairo')),
    );
  }

  Widget _buildSavedContactsBtn() {
    return InkWell(
      onTap: () async {
        final res = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (c) => BeneficiariesScreen(isSelectionMode: true)));
        if (res != null) _fillFormWithBeneficiary(res);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.contacts, size: 16, color: AppColors.primary),
          SizedBox(width: 6),
          Text('من المحفوظين',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary))
        ]),
      ),
    );
  }

  Widget _buildNameFields(bool isMobile) {
    if (isMobile) {
      return Column(children: [
        _buildModernTextField(
            controller: _firstNameController,
            label: 'الاسم الأول',
            icon: Icons.person_outline),
        SizedBox(height: 12),
        _buildModernTextField(
            controller: _fatherNameController,
            label: 'اسم الأب',
            icon: Icons.family_restroom),
        SizedBox(height: 12),
        _buildModernTextField(
            controller: _lastNameController,
            label: 'الكنية',
            icon: Icons.person),
      ]);
    }
    return Row(children: [
      Expanded(
          child: _buildModernTextField(
              controller: _firstNameController,
              label: 'الاسم الأول',
              icon: Icons.person_outline)),
      SizedBox(width: 12),
      Expanded(
          child: _buildModernTextField(
              controller: _fatherNameController,
              label: 'اسم الأب',
              icon: Icons.family_restroom)),
      SizedBox(width: 12),
      Expanded(
          child: _buildModernTextField(
              controller: _lastNameController,
              label: 'الكنية',
              icon: Icons.person)),
    ]);
  }

  Widget _buildDestinationCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('وجهة الحوالة', style: _sectionTitleStyle()),
          SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedCityId > 0 ? _selectedCityId : null,
            decoration: _inputDecoration(
                hintText: 'اختر الفرع',
                prefixIcon: Icons.location_city_rounded),
            items: _cities
                .map((c) => DropdownMenuItem<int>(
                    value: c['cityId'],
                    child: Text(c['cityName'] ?? '',
                        style: TextStyle(fontFamily: 'Cairo'))))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedCityId = v!;
              _selectedCityName =
                  _cities.firstWhere((c) => c['cityId'] == v)['cityName'] ?? '';
            }),
            validator: (v) =>
                (v == null || v == 0) ? 'يرجى اختيار المدينة' : null,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _transferReasonController,
            maxLines: 2,
            inputFormatters: [
              // Sadece harf, rakam ve boşluk. Özel sembolleri girişte engeller.
              FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9\s\u0600-\u06FF]')),
            ],
            decoration: _inputDecoration(
                    hintText: 'سبب التحويل...',
                    prefixIcon: Icons.description_outlined)
                .copyWith(alignLabelWithHint: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'يرجى إدخال السبب';
              if (v.trim().length < 5) return 'السبب قصير جداً وغير واضح';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              if (await _onWillPop()) Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: Text('إلغاء',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: (_isSubmitting ||
                    _limitError != null ||
                    _remainingTransfersCount <= 0)
                ? null
                : () => _showConfirmationDialog(),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text('تأكيد وإرسال',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
          ),
        ),
      ],
    );
  }

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    // Güvenlik: Havale sebebi regex kontrolünü burada da yapıyoruz
    final reason = _transferReasonController.text.trim();
    if (reason.length < 5) {
      _showError('يرجى إدخال سبب تحويل صحيح');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible:
          false, // Diyalog dışına tıklayarak kapatmayı engelle (Güvenlik)
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تأكيد تفاصيل الحوالة',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo')),
            SizedBox(height: 20),
            _confirmRow('المستفيد',
                '${_firstNameController.text.trim()} ${_fatherNameController.text.trim()} ${_lastNameController.text.trim()}'),
            _confirmRow('المبلغ', '$_amount $_currency', isBold: true),
            _confirmRow('الرسوم', '$_fee $_currency'),
            Divider(),
            _confirmRow('الإجمالي', '${_amount + _fee} $_currency',
                isBold: true, color: AppColors.primary),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitTransfer();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('إرسال الآن',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold)),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('تعديل البيانات',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)))
          ],
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String val,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
        Text(val,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color)),
      ]),
    );
  }

  Widget _buildBalanceItem(String cur, double amt, IconData icon, Color col) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: col),
        SizedBox(width: 4),
        Text(cur,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
      ]),
      Text(NumberFormat('#,##0').format(amt),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 5))
          ]);

  TextStyle _sectionTitleStyle() =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo');

  InputDecoration _inputDecoration(
          {required String hintText, required IconData prefixIcon}) =>
      InputDecoration(
        labelText: hintText,
        labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(prefixIcon, color: AppColors.secondary, size: 20),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100)),
      );

  Widget _buildModernTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      textDirection: isPhone ? ui.TextDirection.ltr : null,
      inputFormatters: isPhone
          ? [FilteringTextInputFormatter.digitsOnly]
          : [
              // İsim alanlarında sembolleri engelle (Güvenlik)
              FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z\s\u0600-\u06FF]')),
            ],
      style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
      decoration: _inputDecoration(hintText: label, prefixIcon: icon),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'مطلوب';
        if (!isPhone && v.trim().length < 2) return 'قصير جداً';
        return null;
      },
    );
  }

  Widget _buildLoadingState() => Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text("جاري تحميل البيانات...",
                  style:
                      TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
            ],
          ),
        ),
      );

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false, // Manuel kontrol için
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () async {
          if (await _onWillPop()) Navigator.pop(context);
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
          centerTitle: true,
          title: Text("إرسال حوالة جديدة",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold))),
    );
  }
}
