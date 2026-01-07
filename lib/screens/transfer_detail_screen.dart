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
  String _senderCity = '';
  String _senderName = '';
  String _senderFatherName = '';
  String _senderLastName = '';
  int _amount = 0;
  int _fee = 0;

  // Yazı ile miktar için değişken
  String _amountInWords = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _calculateTransferFee();

      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    // Debug için Fee kontrolü (Konsola bakın)

    final feeData = await ApiService.calculateFee(
        widget.transfer.amount.toInt(), widget.transfer.currency);
    setState(() {
      _fee = feeData['fee'];
      print(feeData);
    });
    print("Gelen Transfer Ücreti (Fee): ${_fee}");

    double totalAmount = widget.transfer.amount + _fee;

    // 2. Bu toplam tutarı yazıya çevir
    String textAmount = ArabicNumberConverter.convert(totalAmount.toInt());
    // Para birimine göre metni düzenle
    String currencyName = widget.transfer.currency.contains("S.P") ||
            widget.transfer.currency.contains("SYP")
        ? "ليرة سورية"
        : "دولار أمريكي";

    if (!mounted) return;

    setState(() {
      _amountInWords = "فقط $textAmount $currencyName لا غير";
    });

    try {
      final senderInfo = await ApiService.getSenderInfo();
      if (mounted) {
        setState(() {
          _senderCity = senderInfo!['cityName'] ?? 'غير محدد';
          _senderName = senderInfo?['cuS_NAME'] ??
              senderInfo?['cusName'] ??
              senderInfo?['CUS_NAME'] ??
              '';
          _senderFatherName =
              senderInfo['cusFatherName'] ?? 'Unknown Sender Father Name';
          _senderLastName =
              senderInfo['cusLastName'] ?? 'Unknown Sender Last Name';
        });
      }
    } catch (e) {
      print("Error fetching info: $e");
    }
  }

  final Color _primaryGold = const Color(0xFFC8A463);
  final Color _textDark = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePdf,
            tooltip: 'مشاركة',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  _buildReceiptCard(),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'جاري المعالجة...',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    String textFee = "${_fee.toStringAsFixed(0)} ${widget.transfer.currency}";

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
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 50,
              decoration: BoxDecoration(
                color: _primaryGold,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(80),
                  bottomLeft: Radius.circular(80),
                ),
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: const Text(
                    "شركة الزاجل للحوالات المالية المحدودة المسؤولية - سجل تجاري",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderLogo(),
                    const SizedBox(height: 20),
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
                        const SizedBox(width: 10),
                        Expanded(child: _buildCapsuleField("من", _senderCity)),
                        Expanded(
                            child: _buildCapsuleField(
                                "إلى", widget.transfer.city)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPersonRow(
                      "المرسل",
                      widget.transfer.isIncoming
                          ? widget.transfer.name
                          : _senderName +
                              ' ' +
                              _senderFatherName +
                              ' ' +
                              _senderLastName,
                    ),
                    const SizedBox(height: 8),
                    _buildPersonRow(
                      "المستفيد",
                      widget.transfer.isIncoming
                          ? _senderName
                          : widget.transfer.name,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildCapsuleField("هاتف",
                                widget.transfer.displayPhone.toString())),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildCapsuleField("موبايل",
                                widget.transfer.displayMobile.toString())),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFC8A463), thickness: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: _buildLabelAndField("المبلغ",
                                "${widget.transfer.amount.toStringAsFixed(0)} ${widget.transfer.currency}",
                                isBold: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildLabelAndField("الأجور", textFee,
                                isSmall: true)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Yazı ile Miktar (Tafqeet Algoritması kullanılarak)
                    _buildLabelAndField("المبلغ كتابة", _amountInWords),

                    const SizedBox(height: 10),
                    _buildLabelAndField(
                        "سبب الحوالة", widget.transfer.transferReason),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "ملاحظة: يعتبر المرسل والمستفيد هو المسؤول عن سبب الحوالة مقابل جميع الجهات العامة",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: _textDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets (Aynı kaldı) ---
  Widget _buildHeaderLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      height: 150,
      child: Image.asset('assets/images/zajelLogo.png', fit: BoxFit.contain),
    );
  }

  Widget _buildLabelAndField(String label, String value,
      {bool isBold = false, bool isSmall = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 2),
          child: Text(
            label,
            textDirection: ui.TextDirection.rtl,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _primaryGold,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _primaryGold.withOpacity(0.5), width: 1),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: _textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapsuleField(String label, String value) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryGold.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textDark, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: double.infinity,
            decoration: BoxDecoration(
              color: _primaryGold.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryGold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonRow(String label, String name) {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildLabelAndField(label, name)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exportPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('حفظ كملف PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sharePdf,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryGold,
              side: BorderSide(color: _primaryGold),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share),
            label: const Text('مشاركة الإيصال',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await _pdfService.createTransferPdf(widget.transfer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ تم حفظ الملف بنجاح'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final file = await _pdfService.createTransferPdf(widget.transfer);
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)],
            text: 'إيصال تحويل - ${widget.transfer.transferNumber}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// -----------------------------------------------------------------------------
// --- GELİŞMİŞ ARAPÇA SAYI ÇEVİRİCİ (TAFQEET) ---
// -----------------------------------------------------------------------------
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
    "اثنا عشر",
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
    "مائة",
    "مائتان",
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

    // Milyarlar (Billions)
    if (number >= 1000000000) {
      int billions = number ~/ 1000000000;
      fullText += _processUnit(billions, "مليار", "ملياران", "مليارات");
      number %= 1000000000;
      if (number > 0) fullText += " و ";
    }

    // Milyonlar (Millions)
    if (number >= 1000000) {
      int millions = number ~/ 1000000;
      fullText += _processUnit(millions, "مليون", "مليونان", "ملايين");
      number %= 1000000;
      if (number > 0) fullText += " و ";
    }

    // Binler (Thousands)
    if (number >= 1000) {
      int thousands = number ~/ 1000;
      // Binler için özel durum: "elf" (1000) ve "elfan" (2000)
      // 3-10 arası "alaf", 11+ "elf"
      fullText +=
          _processUnit(thousands, "ألف", "ألفان", "آلاف", isThousand: true);
      number %= 1000;
      if (number > 0) fullText += " و ";
    }

    // Yüzler ve altı
    if (number > 0) {
      fullText += _convertThreeDigits(number);
    }

    return fullText;
  }

  // Birim işleme (Billion, Million, Thousand)
  static String _processUnit(
      int value, String singular, String dual, String plural,
      {bool isThousand = false}) {
    if (value == 1) return singular;
    if (value == 2) return dual;

    String prefix = _convertThreeDigits(value);

    // Arapça dilbilgisi kuralları (Müfred, Müsenna, Cemi)
    if (value >= 3 && value <= 10) {
      return "$prefix $plural";
    } else {
      // 11'den büyük sayılar için genellikle tekil kullanılır (örn: 15 milyon)
      // Ancak binler için "elf" kullanılır
      String suffix = isThousand ? "ألف" : singular;
      return "$prefix $suffix";
    }
  }

  // 999'a kadar olan sayıları çevirir
  static String _convertThreeDigits(int number) {
    String text = "";

    // Yüzler
    if (number >= 100) {
      text += _hundreds[number ~/ 100];
      number %= 100;
      if (number > 0) text += " و ";
    }

    // Onlar ve Birler
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
