import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static bool _isSnackbarActive = false;

  static void observeNetwork(BuildContext context) {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        _showConnectivitySnackbar(
            context,
            'عذراً، لا يوجد اتصال بالإنترنت', // İnternet yok
            Colors.redAccent,
            Icons.wifi_off_rounded,
            persistent: true);
      } else {
        // İnternet geri geldiğinde kullanıcıya bildirmek istersen:
        if (_isSnackbarActive) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showConnectivitySnackbar(
              context,
              'تم استعادة الاتصال بالإنترنت', // Bağlantı sağlandı
              Colors.green,
              Icons.wifi_rounded,
              persistent: false);
          _isSnackbarActive = false;
        }
      }
    });
  }

  static void _showConnectivitySnackbar(
      BuildContext context, String message, Color color, IconData icon,
      {bool persistent = false}) {
    _isSnackbarActive = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration:
            persistent ? const Duration(days: 1) : const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
