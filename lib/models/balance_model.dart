import 'package:flutter/material.dart';

class BalanceModel {
  final String currency;
  final double amount;
  final String symbol;
  final Color color;

  BalanceModel({
    required this.currency,
    required this.amount,
    required this.symbol,
    required this.color,
  });
}
