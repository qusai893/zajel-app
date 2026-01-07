import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zajel/services/api_service.dart';
import '../models/transfer_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfExportService {
  Future<File> createTransferPdf(TransferModel transfer) async {
    try {
      // 1. API'den bilgi çekme - NULL SAFETY ile
      final senderInfo = await ApiService.getSenderInfo();

      final String currentCityName =
          senderInfo?['cityName'] ?? 'Getting Cities Error';

      final String cusName = senderInfo?['cuS_NAME'] ??
          senderInfo?['cusName'] ??
          senderInfo?['CUS_NAME'] ??
          'User Not Found';
      final String _senderFatherName = senderInfo?['cusFatherName'];
      final String _senderLastName = senderInfo?['cusLastName'];

      final String fullCurrentUserName =
          '$cusName $_senderFatherName $_senderLastName'.trim().isEmpty
              ? 'User Not Found'
              : '$cusName $_senderFatherName $_senderLastName'.trim();

      final String senderNameDisplay =
          transfer.isIncoming ? transfer.name : fullCurrentUserName;

      final String receiverNameDisplay =
          transfer.isIncoming ? fullCurrentUserName : transfer.name;

      int calculatedFee = 0;
      try {
        final feeData = await ApiService.calculateFee(
            transfer.amount.toInt(), transfer.currency);
        calculatedFee = feeData['fee'] ?? 0;
        print('✅ PDF için hesaplanan fee: $calculatedFee');
      } catch (e) {
        print('⚠️ Fee hesaplanamadı, transfer.fee kullanılıyor: $e');
        calculatedFee = transfer.fee.toInt();
      }

      // 4. ⭐ Yazıyla Tutar (Transfer Detail'deki AYNI ALGORİTMA)
      double totalAmount = transfer.amount + calculatedFee;
      String textAmount = ArabicNumberConverter.convert(totalAmount.toInt());

      String currencyName =
          transfer.currency.contains("S.P") || transfer.currency.contains("SYP")
              ? "ليرة سورية"
              : "دولار أمريكي";

      String amountInWords = "فقط $textAmount $currencyName لا غير";

      // 5. Kaynakların Yüklenmesi
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final fontBoldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      final logoBytes = await rootBundle.load('assets/images/zajelLogo.png');
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);

      final pdf = pw.Document();

      // Renkler (Transfer Detail ile AYNI)
      final PdfColor goldColor = PdfColor.fromInt(0xFFC8A463);
      final PdfColor textDark = PdfColor.fromInt(0xFF333333);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttfBold,
          ),
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(15.0),
              child: _buildReceiptVisual(
                transfer: transfer,
                color: goldColor,
                textColor: textDark,
                logoImage: logoImage,
                senderCity: currentCityName,
                senderName: senderNameDisplay,
                receiverName: receiverNameDisplay,
                calculatedFee: calculatedFee,
                amountInWords: amountInWords,
              ),
            );
          },
        ),
      );

      return await _savePdfFile(pdf, transfer);
    } catch (e) {
      print('❌ PDF Service Error: $e');
      rethrow;
    }
  }

  // PDF Görsel Yapısı - Boyutlar küçültüldü
  pw.Widget _buildReceiptVisual({
    required TransferModel transfer,
    required PdfColor color,
    required PdfColor textColor,
    required pw.MemoryImage logoImage,
    required String senderCity,
    required String senderName,
    required String receiverName,
    required int calculatedFee,
    required String amountInWords,
  }) {
    return pw.Container(
      width: 420, // Daha küçük genişlik
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.only(
          topRight: pw.Radius.circular(20),
          bottomRight: pw.Radius.circular(20),
          topLeft: pw.Radius.circular(50),
          bottomLeft: pw.Radius.circular(50),
        ),
        border: pw.Border.all(color: PdfColors.grey400, width: 1.0),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // --- Sol Şerit (Dikey Yazı) ---
          pw.Container(
            width: 35, // Küçültüldü
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(50),
                bottomLeft: pw.Radius.circular(50),
              ),
            ),
            child: pw.Center(
              child: pw.Transform.rotate(
                angle: 1.5708 * 3,
                child: pw.Text(
                  "شركة الزاجل",
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9, // Küçültüldü
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // --- Sağ İçerik ---
          pw.Expanded(
            child: pw.Padding(
              padding:
                  const pw.EdgeInsets.fromLTRB(4, 4, 4, 4), // Daha az padding
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Logo - küçültülmüş
                  _buildHeader(logoImage),

                  // İşlem No ve Tarih
                  _buildFieldRow(
                      "رقم الإشعار", transfer.transferNumber, color, textColor,
                      isBold: true, fontSize: 14), // Font küçültüldü
                  pw.SizedBox(height: 6), // Daha az boşluk
                  _buildFieldRow(
                      "تاريخ الإرسال",
                      DateFormat('yyyy-MM-dd HH:mm').format(transfer.date),
                      color,
                      textColor),

                  pw.SizedBox(height: 8),

                  // Nereden - Nereye
                  pw.Row(
                    children: [
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                          child: _buildCapsule(
                              "من", senderCity, color, textColor)),
                      pw.Expanded(
                          child: _buildCapsule(
                              "إلى", transfer.city, color, textColor)),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // Gönderen / Alıcı
                  pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 3,
                          child: _buildFieldRow(
                              "المرسل", senderName, color, textColor)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 3,
                          child: _buildFieldRow(
                              "المستفيد", receiverName, color, textColor)),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // Telefon Bilgileri
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: _buildCapsule(
                              "هاتف",
                              transfer.displayPhone.toString(),
                              color,
                              textColor)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                          child: _buildCapsule(
                              "موبايل",
                              transfer.displayMobile.toString(),
                              color,
                              textColor)),
                    ],
                  ),

                  pw.SizedBox(height: 10),
                  pw.Divider(color: color, thickness: 0.5), // Daha ince divider
                  pw.SizedBox(height: 8),

                  // Tutar ve Ücret
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: _buildFieldRow(
                              "المبلغ",
                              "${transfer.amount.toStringAsFixed(0)} ${transfer.currency}",
                              color,
                              textColor,
                              isBold: true,
                              fontSize: 13)), // Font küçültüldü
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                          child: _buildFieldRow(
                              "الأجور",
                              "${calculatedFee.toStringAsFixed(0)} ${transfer.currency}",
                              color,
                              textColor,
                              isSmall: true)),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // Yazıyla Tutar
                  _buildFieldRow(
                      "المبلغ كتابة", amountInWords, color, textColor,
                      fontSize: 11), // Daha küçük font

                  pw.SizedBox(height: 8),

                  // Sebep
                  _buildFieldRow(
                      "سبب الحوالة", transfer.transferReason, color, textColor,
                      fontSize: 11),

                  // Alt Not
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6), // Daha az padding
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF3EAD9),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      "ملاحظة: يعتبر المرسل والمستفيد هو المسؤول عن سبب الحوالة مقابل جميع الجهات العامة",
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: 8, // Daha küçük font
                          color: textColor,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  // İmzalar
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildSignature("توقيع المستلم"),
                        _buildSignature("توقيع الموظف"),
                      ]),
                  pw.SizedBox(height: 5) // Minimum boşluk
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Widget'lar (Optimize edildi) ---

  pw.Widget _buildHeader(pw.MemoryImage logoImage) {
    return pw.Container(
      height: 60, // Daha küçük yükseklik
      alignment: pw.Alignment.center,
      child: pw.Image(logoImage,
          fit: pw.BoxFit.contain, height: 50), // Logo küçültüldü
    );
  }

  pw.Widget _buildFieldRow(
      String label, String value, PdfColor color, PdfColor textColor,
      {bool isBold = false, double? fontSize, bool isSmall = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(right: 10, bottom: 2),
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: pw.FontWeight.bold)), // Font küçültüldü
        ),
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.symmetric(
              horizontal: 12, vertical: isSmall ? 6 : 8), // Daha az padding
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(25), // Daha küçük radius
            border: pw.Border.all(
                color: PdfColor.fromInt(0xFFC8A463),
                width: 0.8), // Daha ince border
            color: PdfColors.white,
          ),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize:
                  fontSize ?? (isBold ? 13 : 11), // Default font küçültüldü
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCapsule(
      String label, String value, PdfColor color, PdfColor textColor) {
    return pw.Container(
      height: 32, // Daha küçük yükseklik
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(16), // Daha küçük radius
        border: pw.Border.all(color: PdfColor.fromInt(0xFFC8A463), width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Center(
                child: pw.Text(
              value,
              style: pw.TextStyle(
                  fontSize: 10, // Font küçültüldü
                  fontWeight: pw.FontWeight.bold,
                  color: textColor),
            )),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12), // Daha az padding
            height: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF3EAD9),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(16), // Eşleşen radius
                bottomLeft: pw.Radius.circular(16),
              ),
            ),
            child: pw.Center(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 10, // Font küçültüldü
                      color: color,
                      fontWeight: pw.FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignature(String title) {
    return pw.Column(
      children: [
        pw.Text(title,
            style: const pw.TextStyle(fontSize: 9)), // Font küçültüldü
        pw.SizedBox(height: 15), // Daha az boşluk
        pw.Container(
            width: 60,
            height: 15,
            color: PdfColors.black), // Daha küçük imza çizgisi
      ],
    );
  }

  Future<File> _savePdfFile(pw.Document pdf, TransferModel transfer) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'zajel_transfer_${transfer.transferNumber}_$timestamp.pdf';
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

// -----------------------------------------------------------------------------
// ⭐⭐⭐ ARAPÇA SAYI ÇEVİRİCİ - AYNEN KALDI
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

  static String _processUnit(
      int value, String singular, String dual, String plural,
      {bool isThousand = false}) {
    if (value == 1) return singular;
    if (value == 2) return dual;

    String prefix = _convertThreeDigits(value);

    if (value >= 3 && value <= 10) {
      return "$prefix $plural";
    } else {
      String suffix = isThousand ? "ألف" : singular;
      return "$prefix $suffix";
    }
  }

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
