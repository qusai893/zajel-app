import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zajel/models/transfer_model.dart';
import 'package:zajel/services/api_service.dart';
import 'package:zajel/services/pdf_export_service.dart';
import 'dart:ui' as ui;
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class TransferDetailScreen extends StatefulWidget {
  final TransferModel transfer;

  const TransferDetailScreen({Key? key, required this.transfer})
      : super(key: key);

  @override
  _TransferDetailScreenState createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends State<TransferDetailScreen> {
  final PdfExportService _pdfService = PdfExportService();
  bool _isExporting = false;
  int _fee = 0;
  String _amountInWords = '';

  final Color _primaryGold = const Color(0xFFC8A463);
  final Color _textDark = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // 1. Ücreti Hesapla
    try {
      final feeData = await ApiService.calculateFee(
          widget.transfer.amount.toInt(), widget.transfer.currency);
      if (mounted) {
        setState(() {
          _fee = feeData['fee'] ?? 0;
          _calculateTafqeet();
        });
      }
    } catch (e) {
      print("Fee error: $e");
    }

    // 2. GÖNDERİCİ BİLGİSİ (HIZLANDIRILMIŞ ÇALIŞMA)
    // Eğer AuthProvider içinde bilgi varsa tekrar API'ye sormuyoruz, anında ekrana geliyor.
    if (auth.senderInfo == null) {
      try {
        final info = await ApiService.getSenderInfo();
        if (info != null && mounted) {
          auth.setSenderInfo(info); // Provider'a set et (Cachele)
        }
      } catch (e) {
        print("Sender info fetch error: $e");
      }
    }
  }

  void _calculateTafqeet() {
    double totalAmount = widget.transfer.amount + _fee;
    String textAmount = ArabicNumberConverter.convert(totalAmount.toInt());
    String currencyName = widget.transfer.currency.contains("S.P") ||
            widget.transfer.currency.contains("SYP")
        ? "ليرة سورية"
        : "دولار أمريكي";
    if (mounted) {
      setState(() {
        _amountInWords = "فقط $textAmount $currencyName لا غير";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provider'ı dinle (Bilgi geldiği an UI güncellenir)
    final auth = Provider.of<AuthProvider>(context);
    final senderInfo = auth.senderInfo;

    // Gönderici ve Alıcı İsim Mantığı (Cache'den gelen bilgilerle)
    String displaySender = widget.transfer.isIncoming
        ? widget.transfer.name
        : "${senderInfo?['cuS_NAME'] ?? ''} ${senderInfo?['cusFatherName'] ?? ''} ${senderInfo?['cusLastName'] ?? ''}";

    String displayReceiver = widget.transfer.isIncoming
        ? (senderInfo?['cuS_NAME'] ?? '')
        : widget.transfer.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('إيصال تحويل',
            textDirection: ui.TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _primaryGold,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  _buildReceiptCard(displaySender, displayReceiver,
                      senderInfo?['cityName'] ?? '---'),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isExporting) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(String sender, String receiver, String senderCity) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          topLeft: Radius.circular(80),
          bottomLeft: Radius.circular(80),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSideBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderLogo(),
                    const SizedBox(height: 15),
                    _buildLabelAndField(
                        "رقم الإشعار", widget.transfer.transferNumber),
                    const SizedBox(height: 8),
                    _buildLabelAndField(
                        "تاريخ الإرسال",
                        DateFormat('yyyy-MM-dd HH:mm')
                            .format(widget.transfer.date)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCapsuleField("من", senderCity)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildCapsuleField(
                                "إلى", widget.transfer.city)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLabelAndField("المرسل", sender),
                    const SizedBox(height: 8),
                    _buildLabelAndField("المستفيد", receiver),
                    const SizedBox(height: 12),

                    // TELEFONLAR YAN YANA VE LTR (KARIŞMAZ)
                    Row(
                      children: [
                        Expanded(
                            child: _buildPhoneField(
                                "هاتف", widget.transfer.displayPhone)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildPhoneField(
                                "موبايل", widget.transfer.displayMobile)),
                      ],
                    ),

                    const SizedBox(height: 15),
                    const Divider(color: Color(0xFFC8A463), thickness: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _buildLabelAndField("المبلغ",
                                "${widget.transfer.amount.toStringAsFixed(0)} ${widget.transfer.currency}",
                                isBold: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildLabelAndField("الأجور",
                                "${_fee.toStringAsFixed(0)} ${widget.transfer.currency}",
                                isSmall: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildLabelAndField("المبلغ كتابة", _amountInWords),
                    const SizedBox(height: 10),
                    _buildLabelAndField(
                        "سبب الحوالة", widget.transfer.transferReason),
                    const SizedBox(height: 20),
                    _buildLegalNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Telefonlar için özel LTR Widget
  Widget _buildPhoneField(String label, dynamic value) {
    String phoneText =
        (value == null || value.toString() == "0" || value.toString().isEmpty)
            ? "---"
            : value.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _primaryGold)),
        const SizedBox(height: 2),
        Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primaryGold.withOpacity(0.3)),
          ),
          child: Directionality(
            textDirection: ui.TextDirection.ltr, // Rakamların yerini korur
            child: Text(phoneText,
                style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildSideBanner() {
    return Container(
      width: 45,
      decoration: BoxDecoration(
        color: _primaryGold,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(80), bottomLeft: Radius.circular(80)),
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: const Text(
            "شركة الزاجل للحوالات المالية المحدودة المسؤولية",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLogo() {
    return Container(
        height: 90,
        child: Image.asset('assets/images/zajelLogo.png', fit: BoxFit.contain));
  }

  Widget _buildLabelAndField(String label, String value,
      {bool isBold = false, bool isSmall = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _primaryGold)),
        Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 6 : 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _primaryGold.withOpacity(0.4)),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: _textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildCapsuleField(String label, String value) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryGold.withOpacity(0.4))),
      child: Row(
        children: [
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: double.infinity,
            decoration: BoxDecoration(
                color: _primaryGold.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20))),
            child: Center(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _primaryGold))),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalNote() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: _primaryGold.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8)),
      child: Text(
        "ملاحظة: يعتبر المرسل والمستفيد هو المسؤول عن سبب الحوالة مقابل جميع الجهات العامة",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 9, color: _textDark, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _sharePdf,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGold,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.share, color: Colors.white),
        label: const Text('مشاركة الإيصال',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('جاري المعالجة...',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final file = await _pdfService.createTransferPdf(widget.transfer);
      await Share.shareXFiles([XFile(file.path)],
          text: 'إيصال تحويل - ${widget.transfer.transferNumber}');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// --- ARABIC NUMBER CONVERTER (Aynı kaldı) ---
class ArabicNumberConverter {
  static final List<String> _ones = [
    "",
    "واحد",
    "اثنان",
    "ثلاثة",
    "أربعة",
    "خمسة",
    "ستة",
    "سبعة",
    "ثمانية",
    "تسعة"
  ];
  static final List<String> _teens = [
    "عشرة",
    "أحد عشر",
    "اثna عشر",
    "ثلاثة عشر",
    "أربعة عشر",
    "خمسة عشر",
    "ستة عشر",
    "سبعة عشر",
    "ثمانية عشر",
    "تسعة عشر"
  ];
  static final List<String> _tens = [
    "",
    "عشرة",
    "عشرون",
    "ثلاثون",
    "أربعون",
    "خمسون",
    "ستون",
    "سبعون",
    "ثمانون",
    "تسعون"
  ];
  static final List<String> _hundreds = [
    "",
    "مئة",
    "مئتان",
    "ثلاثمائة",
    "أربعمائة",
    "خمسمائة",
    "ستمائة",
    "سبعمائة",
    "ثمانمائة",
    "تسعمائة"
  ];

  static String convert(int number) {
    if (number == 0) return "صفر";
    String fullText = "";
    if (number >= 1000000000) {
      int billions = number ~/ 1000000000;
      fullText += _processUnit(billions, "مليار", "مليارan", "مليارات");
      number %= 1000000000;
      if (number > 0) fullText += " و ";
    }
    if (number >= 1000000) {
      int millions = number ~/ 1000000;
      fullText += _processUnit(millions, "مليون", "مليونan", "ملايين");
      number %= 1000000;
      if (number > 0) fullText += " و ";
    }
    if (number >= 1000) {
      int thousands = number ~/ 1000;
      fullText +=
          _processUnit(thousands, "ألف", "ألفين", "آلاف", isThousand: true);
      number %= 1000;
      if (number > 0) fullText += " و ";
    }
    if (number > 0) fullText += _convertThreeDigits(number);
    return fullText;
  }

  static String _processUnit(
      int value, String singular, String dual, String plural,
      {bool isThousand = false}) {
    if (value == 1) return singular;
    if (value == 2) return dual;
    String prefix = _convertThreeDigits(value);
    if (value >= 3 && value <= 10) return "$prefix $plural";
    return "$prefix ${isThousand ? "ألف" : singular}";
  }

  static String _convertThreeDigits(int number) {
    String text = "";
    if (number >= 100) {
      text += _hundreds[number ~/ 100];
      number %= 100;
      if (number > 0) text += " و ";
    }
    if (number >= 10 && number <= 19) {
      text += _teens[number - 10];
    } else if (number >= 20) {
      int onesDigit = number % 10;
      int tensDigit = number ~/ 10;
      if (onesDigit > 0) {
        text += _ones[onesDigit];
        text += " و ";
      }
      text += _tens[tensDigit];
    } else if (number > 0) {
      text += _ones[number];
    }
    return text;
  }
}
