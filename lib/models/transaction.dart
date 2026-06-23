class Transaction {
  final int? id;
  final double amount;
  final String type; // 'income' | 'expense'
  final String merchantOrSender;
  final String category;
  final String source; // 'sms' | 'manual'
  final String? note;
  final DateTime transactionDate;
  final String? rawSms;
  final String? referenceNumber;

  Transaction({
    this.id,
    required this.amount,
    required this.type,
    required this.merchantOrSender,
    required this.category,
    required this.source,
    this.note,
    required this.transactionDate,
    this.rawSms,
    this.referenceNumber,
  });

  Transaction copyWith({
    int? id,
    double? amount,
    String? type,
    String? merchantOrSender,
    String? category,
    String? source,
    String? note,
    DateTime? transactionDate,
    String? rawSms,
    String? referenceNumber,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchantOrSender: merchantOrSender ?? this.merchantOrSender,
      category: category ?? this.category,
      source: source ?? this.source,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      rawSms: rawSms ?? this.rawSms,
      referenceNumber: referenceNumber ?? this.referenceNumber,
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: double.parse(json['amount'].toString()),
      type: json['type'],
      merchantOrSender: json['merchant_or_sender'] ?? 'Unknown',
      category: json['category'] ?? 'Uncategorized',
      source: json['source'] ?? 'manual',
      note: json['note'],
      transactionDate: DateTime.parse(json['transaction_date']),
      rawSms: json['raw_sms'],
      referenceNumber: json['reference_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type,
      'merchant_or_sender': merchantOrSender,
      'category': category,
      'source': source,
      'note': note,
      'transaction_date': transactionDate.toIso8601String(),
      'raw_sms': rawSms,
      'reference_number': referenceNumber,
    };
  }

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
}
