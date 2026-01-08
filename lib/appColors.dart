import 'package:flutter/material.dart';

class AppColors {
  // --- İstenilen Renk Paleti ---
  static const Color primary = Color(0xFFD8AB59); // Gold (Ana Renk)
  static const Color secondary = Color(0xFF888888); // Gri (İkincil)
  static const Color background = Color(0xFFEEE0C8); // Krem (Arkaplan)
  static const Color textPrimary = Color(0xFF4F4F4F); // Koyu Gri (Metin)

  // --- Yardımcı Renkler (Silinmedi, palette uyumlu hale getirildi) ---
  static const Color card = Color(0xFFFFFFFF); // Beyaz Kart
  static const Color textSecondary =
      Color(0xFF888888); // İkincil metin için secondary kullanıldı
  static const Color error = Color(0xFFD32F2F); // Standart Hata kırmızısı
  static const Color success = Color(0xFF388E3C); // Standart Başarı yeşili
  static const Color border = Color(0xFFE0E0E0); // Açık gri sınır çizgileri
  static const Color accent = Color(0xFFBFA063); // Gold'un koyu tonu

  // --- Gradientler (Tasarım için eklendi/güncellendi) ---
  static Gradient primaryGradient = const LinearGradient(
    colors: [
      Color(0xFFD8AB59), // Primary
      Color(0xFFF0C876), // Biraz daha açık gold
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Gradient backgroundGradient = const LinearGradient(
    colors: [
      Color(0xFFEEE0C8), // Background
      Color(0xFFF5EBD9), // Biraz daha açık krem
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// --- Tema Ayarları ---
ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: 'Cairo', // Arapça uyumlu font
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.card,
    surfaceTint: Colors.white,
    error: AppColors.error,
  ),
  useMaterial3: true,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    labelStyle: const TextStyle(
      color: AppColors.secondary,
      fontSize: 14,
      fontFamily: 'Cairo',
      fontWeight: FontWeight.w500,
    ),
    prefixIconColor: AppColors.primary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      shadowColor: AppColors.primary.withOpacity(0.4),
    ),
  ),
);


// bu dosya da aynı şekide ilerliceksin 
// mantığa dokunmak yok 
// sadece profesyonel ve responsive tasarım  
// sen profesyonel bir UI/UX developer'sın 
// frontend'te uzmansın 
// ona göre hareket et 