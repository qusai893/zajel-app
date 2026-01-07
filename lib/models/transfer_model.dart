import 'package:flutter/material.dart';

// models/transfer_model.dart
class TransferModel {
  final String transferId;
  final String transferNumber;
  final DateTime date;
  final double amount;
  final String currency;
  final String name;
  final String city;
  final int status;
  final String statusText;
  final bool isIncoming; // true: gelen, false: giden
  final String transferReason;
  final double fee;
  final double totalAmount;
  final String notes;
  final TransferType? type;
  final String? receiverPhone;
  final String? receiverMobile;

  TransferModel({
    required this.transferId,
    required this.transferNumber,
    required this.date,
    required this.amount,
    required this.currency,
    required this.name,
    required this.city,
    required this.status,
    required this.statusText,
    required this.isIncoming,
    required this.transferReason,
    required this.fee,
    required this.totalAmount,
    required this.notes,
    this.receiverPhone,
    this.receiverMobile,
    this.type,
  });

  Color get statusColor {
    switch (status) {
      case 1:
        return Colors.orange; // Gönderildi
      case 2:
        return Colors.green; // Teslim edildi
      default:
        return Colors.grey;
    }
  }

  factory TransferModel.fromJson(
      Map<String, dynamic> json, bool isIncoming, TransferType? type) {
    return TransferModel(
      transferId: json['transferId']?.toString() ?? '',
      transferNumber: json['transferNumber']?.toString() ?? '',
      date: DateTime.parse(
          json['transferDate']?.toString() ?? DateTime.now().toString()),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'SYP',
      name: isIncoming
          ? json['senderName']?.toString() ?? ''
          : json['receiverName']?.toString() ?? '',
      city: isIncoming
          ? json['senderCity']?.toString() ?? ''
          : json['receiverCity']?.toString() ?? '',
      status: (json['status'] as int?) ?? 1,
      statusText: json['statusText']?.toString() ?? 'غير معروف',
      isIncoming: isIncoming,
      receiverPhone: json['receiverPhone']?.toString() ?? '',
      receiverMobile: json['receiverMobile']?.toString() ?? '',
      transferReason: json['transferReason']?.toString() ?? '',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      notes: json['senderNotes']?.toString() ?? '',
      type: type,
    );
  }
  // UI'da kullanmak için bu iki yardımcıyı modelin içine (en alta) ekleyin:
  String get displayPhone => (receiverPhone == null ||
          receiverPhone!.isEmpty ||
          receiverPhone == "null")
      ? 'لا يوجد رقم'
      : receiverPhone!;

  String get displayMobile => (receiverMobile == null ||
          receiverMobile!.isEmpty ||
          receiverMobile == "null")
      ? 'لا يوجد رقم'
      : receiverMobile!;
}

enum TransferType { sent, received, all }
