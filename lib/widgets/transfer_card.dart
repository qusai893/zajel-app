import 'package:flutter/material.dart';
import 'package:zajel/appColors.dart';
import 'package:zajel/models/transfer_model.dart';
import 'package:intl/intl.dart';
import 'package:zajel/screens/transfer_detail_screen.dart';

class TransferCard extends StatelessWidget {
  final TransferModel transfer;

  const TransferCard({Key? key, required this.transfer}) : super(key: key);

  // --- Mantık Metotları (Dokunulmadı, sadece renkler AppColors ile uyumlu hale getirildi) ---
  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange; // Gönderildi
      case 2:
        return Colors.green; // Teslim edildi
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'تم الارسال';
      case 2:
        return 'تم الاستلام';
      default:
        return 'غير معروف ';
    }
  }

  // --- UI TASARIMI ---
  @override
  Widget build(BuildContext context) {
    final isSent = transfer.type == TransferType.sent;
    final primaryColor = isSent
        ? AppColors.primary
        : AppColors.success; // Gönderilen Gold, Alınan Yeşil

    return GestureDetector(
      onLongPress: () => {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TransferDetailScreen(transfer: transfer)))
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // 1. Üst Kısım (Ana Bilgiler)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // İkon Kutusu
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isSent
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // İsim ve Tarih
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transfer.name, // Karşı tarafın ismi
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                isSent ? 'إرسال إلى' : 'استلام من',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontFamily: 'Cairo'),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.circle,
                                  size: 4, color: AppColors.border),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(transfer.date),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tutar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${transfer.amount.toStringAsFixed(0)} ${transfer.currency}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSent
                                ? AppColors.textPrimary
                                : AppColors.success,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Durum Rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(transfer.status)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusText(transfer.status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(transfer.status),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Kesik Çizgi veya Ayırıcı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                    height: 1, color: AppColors.border.withOpacity(0.4)),
              ),

              // 3. Alt Kısım (Detaylar - Genişletilebilir veya Özet)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.background.withOpacity(0.3),
                child: Column(
                  children: [
                    // Numara ve Şehir
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_outlined,
                                size: 14, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Text(
                              transfer.transferNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              transfer.city,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Varsa Sebep veya Not (Sadece birini gösterelim, kalabalık olmasın)
                    if (transfer.transferReason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 14,
                                color: AppColors.primary.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                transfer.transferReason,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Cairo',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
