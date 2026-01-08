import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zajel/appColors.dart';
import 'package:zajel/models/beneficiary_model.dart';
import 'package:zajel/screens/beneficiaries_screen.dart';
import 'package:zajel/screens/dashboard_screen.dart';
import 'package:zajel/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:zajel/services/beneficiary_service.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'dart:ui' as ui;

class NewTransferScreen extends StatefulWidget {
  // Opsiyonel parametre ekliyoruz
  final BeneficiaryModel? initialBeneficiary;

  // Constructor'ı güncelle
  NewTransferScreen({this.initialBeneficiary});
  @override
  _NewTransferScreenState createState() => _NewTransferScreenState();
}

class _NewTransferScreenState extends State<NewTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  Timer? _debounce;
  // Form variables
  int _amount = 0;
  String _currency = 'USD';
  int _fee = 0;
  int _totalAmount = 0;

  // Receiver information
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

  // City information
  int _selectedCityId = 0;
  String _selectedCityName = '';

  // Sender information (API'den gelen diğer veriler için)
  String _notificationNumber = '';
  String _transferDate = '';
  // Not: Bakiye bilgileri artık Provider'dan alınacak.

  // API data
  List<dynamic> _cities = [];
  bool _isLoading = false;
  bool _isCalculating = false;
  bool _isExistingReceiver = false;
  bool _checkingReceiver = false;

  @override
  void initState() {
    super.initState();
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

  void _fillFormWithBeneficiary(BeneficiaryModel person) {
    setState(() {
      _firstNameController.text = person.firstName;
      _fatherNameController.text = person.fatherName;
      _lastNameController.text = person.lastName;
      _receiverPhoneController.text = person.phone;
      _receiverMobilePhoneController.text = person.mobile;

      _selectedCityId = person.cityId;
      _selectedCityName = person.cityName;

      _checkReceiver();
    });
  }

  void _onNameChanged() {
    if (_firstNameController.text.isNotEmpty &&
        _fatherNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 1000), () {
        _checkReceiver();
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _fatherNameController.dispose();
    _lastNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverMobilePhoneController.dispose();
    _transferReasonController.dispose();
    _senderNotesController.dispose();
    super.dispose();
  }

  Future<void> _calculateTransferFee() async {
    if (_amount <= 0) return;

    setState(() => _isCalculating = true);

    try {
      final feeData = await ApiService.calculateFee(_amount.toInt(), _currency);
      setState(() {
        _fee = feeData['fee']?.toInt() ?? 0;

        _totalAmount =
            feeData['totalAmount']?.toInt() ?? (_amount.toInt() + _fee.toInt());
      });
    } catch (e) {
      print('Ücret hesaplama hatası: $e');
      setState(() {
        _fee = 0;
        _totalAmount = _amount;
      });
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final cities = await ApiService.getCities();
      setState(() => _cities = cities);

      await ApiService.getSenderInfo();

      _notificationNumber = await ApiService.generateNotificationNumber();
      _transferDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('لم يتم تحميل البيانات ,تفقد اتصالك بالانترنت'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkReceiver() async {
    if (_firstNameController.text.isEmpty ||
        _fatherNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) return;

    setState(() => _checkingReceiver = true);
    try {
      final exists = await ApiService.checkReceiverExists(
          _firstNameController.text,
          _fatherNameController.text,
          _lastNameController.text);
      setState(() => _isExistingReceiver = exists);
    } catch (e) {
      print('Check receiver error: $e');
    } finally {
      setState(() => _checkingReceiver = false);
    }
  }

  Future<void> _submitTransfer() async {
    String phone = _receiverPhoneController.text.trim();
    String mobile = _receiverMobilePhoneController.text.trim();

    if (!phone.startsWith('09') || !mobile.startsWith('09')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('عفواً، يجب أن تكون الأرقام سورية تبدأ بـ 09',
            style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // 1. BAKİYE KONTROLÜ (YENİ EKLENDİ)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final customer = authProvider.currentCustomer;

      double currentBalance = 0.0;
      if (_currency == 'USD') {
        currentBalance = customer?.cusBalanceDollar.toDouble() ?? 0.0;
      } else {
        currentBalance = customer?.cusBalanceSyr.toDouble() ?? 0.0;
      }

      // Hesaplanan toplam tutar (Tutar + Komisyon)
      int finalTotalAmount = _totalAmount > 0 ? _totalAmount : (_amount + _fee);

      // Bakiye yetersizse işlemi durdur
      if (finalTotalAmount > currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('عفواً، رصيدك غير كافي لإتمام هذه العملية',
                  style: TextStyle(fontFamily: 'Cairo')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ));
        return; // Fonksiyondan çık
      }
      final feeData = await ApiService.calculateFee(_amount.toInt(), _currency);
      _fee = feeData['fee']?.toInt() ?? 0;
      // Bakiye yeterliyse işleme devam et
      setState(() => _isLoading = true);
      try {
        final transferData = {
          'amount': _amount.toInt(),
          'currency': _currency.trim(),
          'totalAmount': (_totalAmount + _fee).toInt(),
          'receiverName': _firstNameController.text.trim(),
          'receiverFatherName': _fatherNameController.text.trim(),
          'receiverLastName': _lastNameController.text.trim(),
          'receiverCityId': _selectedCityId,
          'receiverPhone': _receiverPhoneController.text.trim(),
          'receiverMobilePhone': _receiverMobilePhoneController.text.trim(),
          'transferReason': _transferReasonController.text.trim(),
          'senderNotes': _senderNotesController.text.trim(),
        };

        final result = await ApiService.sendTransfer(transferData);

        if (result['success'] == true) {
          try {
            final newBeneficiary = BeneficiaryModel(
              firstName: _firstNameController.text.trim(),
              fatherName: _fatherNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              phone: _receiverPhoneController.text.trim(),
              mobile: _receiverMobilePhoneController.text.trim(),
              cityId: _selectedCityId,
              cityName: _selectedCityName.trim(),
            );

            // Arka planda kaydet (await kullanmayabiliriz ki UI donmasın)
            BeneficiaryService.saveBeneficiary(newBeneficiary);
          } catch (e) {
            print("Kişi kaydedilemedi: $e");
          }
          // Bakiye güncelleme
          authProvider.updateBalance(
              currency: _currency, amount: finalTotalAmount);

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await authProvider.refreshUserInfo();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('✅ تم إرسال الحوالة بنجاح')
                  ]),
                  Text('رقم الإشعار: ${result['transferNumber']}'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );

          await Future.delayed(Duration(seconds: 2));

          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['message'] ?? 'خطأ في الإرسال'),
              backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- PROVIDER VERİLERİNİ BURADA ALIYORUZ ---
    final authProvider = Provider.of<AuthProvider>(context);
    final customer = authProvider.currentCustomer;
    // null kontrolü ile varsayılan değerler
    final double syrBalance = customer?.cusBalanceSyr.toDouble() ?? 0.0;
    final double dollarBalance = customer?.cusBalanceDollar.toDouble() ?? 0.0;
    final String senderName = customer?.cusName ?? '';
    final String senderLastName = customer?.cusLastName ?? '';
    final String senderFatherName = customer?.cusFatherName ?? '';

    return Scaffold(
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
                            horizontal: isMobile ? 16 : 32, vertical: 20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Gönderici Kartına Bakiyeleri Gönderiyoruz
                                  _buildSenderCard(
                                      isMobile,
                                      senderName +
                                          ' ' +
                                          senderFatherName +
                                          ' ' +
                                          senderLastName,
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
    );
  }

  // --- GÜNCELLENEN GÖNDERİCİ KARTI ---
  Widget _buildSenderCard(
      bool isMobile, String name, double syrBalance, double dollarBalance) {
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
                Icon(Icons.wallet, color: AppColors.primary), // İkon değişti
                SizedBox(width: 10),
                Text(
                  'المحفظة والرصيد', // Başlık değişti
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _notificationNumber,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // İsim Alanı
                Row(
                  children: [
                    Icon(Icons.person, size: 18, color: AppColors.secondary),
                    SizedBox(width: 8),
                    Text('المرسل: ',
                        style: TextStyle(
                            fontFamily: 'Cairo', color: AppColors.secondary)),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                Divider(height: 24),
                // Bakiye Alanları (Yan Yana)
                Row(
                  children: [
                    Expanded(
                        child: _buildBalanceItem('USD', dollarBalance,
                            Icons.attach_money, Colors.green)),
                    Container(
                        width: 1, height: 40, color: Colors.grey.shade300),
                    Expanded(
                        child: _buildBalanceItem(
                            'SYP', syrBalance, Icons.money, Colors.blue)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bakiye Gösterimi İçin Yardımcı Widget
  Widget _buildBalanceItem(
      String currency, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 4),
            Text(currency,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontFamily: 'Cairo')),
          ],
        ),
        SizedBox(height: 4),
        Text(
          NumberFormat('#,##0.##').format(amount),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo'),
        ),
      ],
    );
  }

  // --- DİĞER UI METOTLARI (AYNEN KORUNDU) ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration:
                BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Text('جاري التحضير...', style: TextStyle(fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'إرسال حوالة جديدة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Icon(Icons.send_rounded,
                    size: 150, color: Colors.white.withOpacity(0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildInfoItem artık kullanılmadığı için kaldırılabilir veya tutulabilir.
  // ...

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
                  // ÇÖZÜM: Sayı girişi yapılan alanı zorunlu olarak Soldan Sağa (LTR) yapıyoruz
                  textDirection: ui.TextDirection.ltr,
                  child: TextFormField(
                    // decimal: true yaptık ama inputFormatter'da sadece rakam izin verdin,
                    // Eğer kuruş/sent gönderilecekse digitsOnly kaldırılmalı.
                    // Şimdilik tam sayı üzerinden gidiyoruz:
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      _currency == "USD"
                          ? LengthLimitingTextInputFormatter(
                              7) // 10 Milyon Dolar sınırı (Güvenlik)
                          : LengthLimitingTextInputFormatter(
                              12) // Suriye Lirası sınırı
                    ],
                    // İmlecin ve yazının yerini sabitlemek için:
                    textAlign: TextAlign.left,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo'),
                    decoration: _inputDecoration(
                      hintText: '0',
                      prefixIcon: Icons.money_rounded,
                    ).copyWith(
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      // Hint text'in de solda durması için:
                      hintTextDirection: ui.TextDirection.ltr,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'مطلوب';
                      final n = num.tryParse(value);
                      if (n == null) return 'رقم غير صحيح';
                      if (n <= 0) return 'يجب أن يكون أكبر من 0';

                      // Ekstra Güvenlik: Mantıksız yüksek rakamları engelle (Örn: 1 milyar dolar)
                      if (_currency == 'USD' && n > 1000000)
                        return 'المبلغ كبير جداً';
                      return null;
                    },
                    onChanged: (value) async {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                      _debounce =
                          Timer(const Duration(milliseconds: 600), () async {
                        String cleanValue = value.trim();
                        if (cleanValue.isNotEmpty &&
                            int.tryParse(cleanValue) != null) {
                          setState(() => _amount = int.parse(cleanValue));
                          // Kullanıcı yazmayı bitirdikten 600ms sonra hesapla
                          await _calculateTransferFee();
                        } else {
                          setState(() {
                            _amount = 0;
                            _fee = 0;
                            _totalAmount = 0;
                          });
                        }
                      });
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
                      hintText: '',
                      prefixIcon: Icons.currency_exchange,
                    ),
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
                    onChanged: (value) async {
                      setState(() => _currency = value ?? 'USD');
                      if (_amount > 0) await _calculateTransferFee();
                    }),
              ),
            ],
          ),
          if (_fee > 0 || _isCalculating)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('رسوم التحويل:',
                        style: TextStyle(
                            fontFamily: 'Cairo', color: AppColors.secondary)),
                    _isCalculating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            '${_fee.toStringAsFixed(2)} ${_currency == 'USD' ? 'USD' : 'ل.س'}',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                  ],
                ),
              ),
            ),
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
          // --- BAŞLIK VE BUTON SATIRI ---
          Row(
            children: [
              Text('بيانات المستفيد', style: _sectionTitleStyle()),
              Spacer(), // Başlığı sola, diğerlerini sağa iter

              // 1. Durum İkonları (Yükleniyor veya Eski Müşteri)
              if (_checkingReceiver)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_isExistingReceiver)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('عميل سابق',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontFamily: 'Cairo')),
                    ],
                  ),
                ),

              // 2. REHBERDEN SEÇ BUTONU (YENİ)
              InkWell(
                onTap: () async {
                  // Rehber sayfasını seçim modunda aç
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BeneficiariesScreen(isSelectionMode: true),
                    ),
                  );

                  // Eğer bir kişi seçildiyse formu doldur
                  if (result != null && result is BeneficiaryModel) {
                    _fillFormWithBeneficiary(result);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.contacts_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'من المحفوظين', // "Kayıtlılardan"
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // --- İSİM ALANLARI (DEĞİŞMEDİ) ---
          if (isMobile)
            Column(
              children: [
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
              ],
            )
          else
            Row(
              children: [
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
              ],
            ),
          SizedBox(height: 20),

          // --- TELEFON ALANLARI (DEĞİŞMEDİ) ---
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: ui.TextDirection.rtl,
                  child: _buildModernTextField(
                    controller: _receiverPhoneController,
                    label: 'الهاتف',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.number,
                    isPhone: true,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildModernTextField(
                  controller: _receiverMobilePhoneController,
                  label: 'الموبايل',
                  icon: Icons.smartphone_outlined,
                  keyboardType: TextInputType.number,
                  isPhone: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              prefixIcon: Icons.location_city_rounded,
            ),
            items: _cities.map<DropdownMenuItem<int>>((city) {
              return DropdownMenuItem<int>(
                value: city['cityId'] ?? city['CityId'],
                child: Text(city['cityName'] ?? city['CityName'] ?? '',
                    style: TextStyle(fontFamily: 'Cairo')),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCityId = value ?? 0;
                _selectedCityName = _cities.firstWhere(
                        (c) => (c['cityId'] ?? c['CityId']) == value,
                        orElse: () => {})['cityName'] ??
                    '';
              });
            },
            validator: (value) =>
                (value == null || value == 0) ? 'يرجى اختيار المدينة' : null,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _transferReasonController,
            maxLines: 3,
            decoration: _inputDecoration(
              hintText: 'سبب التحويل...',
              prefixIcon: Icons.description_outlined,
            ).copyWith(alignLabelWithHint: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'يرجى إدخال السبب';
              if (value.length < 10) return 'يجب أن يكون 10 أحرف على الأقل';
              return null;
            },
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.secondary),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'يعتبر المرسل والمستفيد مسؤولين عن سبب الحوالة.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary,
                      fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5)),
      ],
    );
  }

  TextStyle _sectionTitleStyle() {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
      fontFamily: 'Cairo',
    );
  }

  InputDecoration _inputDecoration(
      {required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      labelText: hintText.isNotEmpty ? hintText : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.error)),
      prefixIcon: Icon(prefixIcon, color: AppColors.secondary),
      labelStyle: TextStyle(color: AppColors.secondary, fontFamily: 'Cairo'),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPhone = false,
  }) {
    return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: isPhone ? ui.TextDirection.ltr : null,
        textAlign: isPhone ? TextAlign.left : TextAlign.start,
        // --- DÜZELTME BURADA ---
        inputFormatters: isPhone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                FilteringTextInputFormatter.deny(
                    RegExp(r'\s')), // Sadece rakamlara izin verir
                LengthLimitingTextInputFormatter(
                    15), // Güvenlik: Çok uzun inputları engeller
              ]
            : null,
        // -----------------------
        style: TextStyle(
          fontSize: 16,
          fontFamily: 'Cairo',
          fontWeight: isPhone ? FontWeight.bold : FontWeight.normal,
          letterSpacing: isPhone ? 1.0 : 0.0,
        ),
        decoration:
            _inputDecoration(hintText: label, prefixIcon: icon).copyWith(
          hintTextDirection: isPhone ? ui.TextDirection.ltr : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'مطلوب';

          if (isPhone) {
            final cleanValue = value.trim();

            if (!cleanValue.startsWith('09')) {
              return 'يجب أن يبدأ الرقم بـ 09 (سوريا)';
            }
            if (cleanValue.length < 10) {
              return 'رقم الهاتف يجب أن يكون \n 10 أرقام';
            }
          }
          return null;
        });
  }

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text('إلغاء',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () => _showConfirmationDialog(),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_rounded, size: 20),
                SizedBox(width: 8),
                Text('تأكيد وإرسال',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showConfirmationDialog() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('يرجى ملء جميع الحقول'),
          backgroundColor: Colors.orange));
      return;
    }
    _formKey.currentState!.save();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: EdgeInsets.all(24),
            constraints: BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.receipt_long_rounded,
                        color: AppColors.primary, size: 32),
                  ),
                  SizedBox(height: 16),
                  Text('تأكيد تفاصيل الحوالة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
                  SizedBox(height: 24),
                  _buildConfirmRow('المستفيد',
                      '${_firstNameController.text} ${_fatherNameController.text} ${_lastNameController.text}'),
                  Divider(),
                  _buildConfirmRow(
                      'المبلغ', '${_amount.toStringAsFixed(2)} $_currency',
                      isBold: true),
                  if (_fee > 0)
                    _buildConfirmRow(
                        'الرسوم', '${_fee.toStringAsFixed(2)} $_currency'),
                  Divider(),
                  _buildConfirmRow('الإجمالي',
                      '${(_totalAmount).toStringAsFixed(2)} $_currency',
                      isBold: true, color: AppColors.primary),
                  _buildConfirmRow('الوجهة', _selectedCityName),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text('لا يمكن إلغاء الحوالة بعد الإرسال.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[800],
                                    fontFamily: 'Cairo'))),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('تعديل',
                              style: TextStyle(
                                  color: AppColors.secondary,
                                  fontFamily: 'Cairo')),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _isLoading ? null : _submitTransfer();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('إرسال الآن',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Cairo',
                  fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Cairo',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
