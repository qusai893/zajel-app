import 'package:flutter/material.dart';
import 'package:zajel/appColors.dart';
import 'package:zajel/models/transfer_model.dart';

class TransferFilterChip extends StatelessWidget {
  final TransferType type;
  final bool isSelected;
  final VoidCallback onTap;

  const TransferFilterChip({
    Key? key,
    required this.type,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // İkon ve metin seçimi
    IconData getIcon() {
      switch (type) {
        case TransferType.all:
          return Icons.grid_view_rounded;
        case TransferType.sent:
          return Icons.arrow_upward_rounded;
        case TransferType.received:
          return Icons.arrow_downward_rounded;
        default:
          return Icons.circle;
      }
    }

    String getLabel() {
      // Modeldeki enum name yerine Arapça metinleri buraya da ekleyebiliriz veya modelden geleni kullanırız.
      // Burada hardcode Arapça daha güvenli UI için:
      switch (type) {
        case TransferType.all:
          return 'الكل';
        case TransferType.sent:
          return 'مرسلة';
        case TransferType.received:
          return 'مستلمة';
        default:
          return type.name;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getIcon(),
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              getLabel(),
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
