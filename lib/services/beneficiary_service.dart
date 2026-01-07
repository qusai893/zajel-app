import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/beneficiary_model.dart';

class BeneficiaryService {
  static const String _storageKey = 'saved_beneficiaries';

  // Kaydet (Varsa ekleme)
  static Future<void> saveBeneficiary(BeneficiaryModel newPerson) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList(_storageKey) ?? [];

    // Telefon numarasına göre kontrol et (Aynı kişi tekrar kaydedilmesin)
    bool exists = savedList.any((item) {
      final p = BeneficiaryModel.fromJson(jsonDecode(item));
      return p.mobile == newPerson.mobile;
    });

    if (!exists) {
      savedList.add(jsonEncode(newPerson.toJson()));
      await prefs.setStringList(_storageKey, savedList);
    }
  }

  // Listeyi Getir
  static Future<List<BeneficiaryModel>> getBeneficiaries() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList(_storageKey) ?? [];

    return savedList
        .map((item) => BeneficiaryModel.fromJson(jsonDecode(item)))
        .toList();
  }

  // Silme (Opsiyonel)
  static Future<void> deleteBeneficiary(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList(_storageKey) ?? [];

    savedList.removeWhere((item) {
      final p = BeneficiaryModel.fromJson(jsonDecode(item));
      return p.mobile == mobile;
    });

    await prefs.setStringList(_storageKey, savedList);
  }
}
