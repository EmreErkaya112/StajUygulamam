// lib/transactions_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // sadece gölgeler için
import 'package:http/http.dart' as http;
import 'dart:convert';

// 🔽 transactions_page.dart içinde, en üste değil Transaction sınıfının olduğu yere koy
num _numify(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}

int _asInt(dynamic v) => _numify(v).round();
double _asDouble(dynamic v) => _numify(v).toDouble();
String _asString(dynamic v) => v?.toString() ?? '';

DateTime _asDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is int) {
    // epoch saniye/ms gelirse
    if (v > 10000000000) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }
  final s = v.toString().replaceFirst(' ', 'T'); // "YYYY-MM-DD HH:MM:SS" -> ISO
  return DateTime.tryParse(s) ?? DateTime.now();
}

class Transaction {
  final int id;
  final String type;      // "income" | "expense"
  final double amount;
  final String category;
  final String description;
  final DateTime date;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) {
    return Transaction(
      id: _asInt(j['id']),
      type: _asString(j['type']),
      amount: _asDouble(j['amount']),
      category: _asString(j['category']),
      description: _asString(j['description']),
      date: _asDate(j['date']),
    );
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  bool _loading = true;
  List<Transaction> _all = [];
  DateTime _filterMonth = DateTime.now();
  String _filterType = 'all'; // 'all', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('https://yagmurlukoyu.org/api/get_transactions.php'),
      );
      if (res.statusCode != 200) throw 'Sunucu hatası ${res.statusCode}';
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) throw 'API hatası';
      final list = (body['data'] as List)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _all = list);
    } catch (e) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Hata'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              child: const Text('Tamam'),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Transaction> get _filtered {
    return _all.where((t) {
      final sameMonth = t.date.year == _filterMonth.year &&
          t.date.month == _filterMonth.month;
      final typeOk = _filterType == 'all' || t.type == _filterType;
      return sameMonth && typeOk;
    }).toList();
  }

  double get _sumIncome =>
      _filtered.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
  double get _sumExpense =>
      _filtered.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

  void _pickMonth() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => SafeArea(
        // En alt güvenli alana uy,
        bottom: true,
        child: Container(
          height: 260,
          color: CupertinoColors.systemBackground,
          // Eğer yine taşma olursa, aşağıdaki satırı aktifleştirin:
          // padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _filterMonth,
                  onDateTimeChanged: (dt) {
                    setState(() {
                      // Yalnızca ay‑yıl değişsin, gün hep 1 olsun
                      _filterMonth = DateTime(dt.year, dt.month);
                    });
                  },
                ),
              ),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Seç'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _summaryCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, color: CupertinoColors.inactiveGray)),
            const SizedBox(height: 6),
            Text(
              '${amount.toStringAsFixed(2)} ₺',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return CupertinoPageScaffold(
      navigationBar:
      CupertinoNavigationBar(middle: const Text('Gelir & Giderler')),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
          children: [
            // ▬▬ Filtreler ▬▬
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Ay seçici
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    color: CupertinoColors.systemGrey6,
                    child: Text(
                      '${_filterMonth.year}-${_filterMonth.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600),
                    ),
                    onPressed: _pickMonth,
                  ),
                  const SizedBox(width: 12),
                  // Tür segment
                  Expanded(
                    child: CupertinoSegmentedControl<String>(
                      children: const {
                        'all': Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Tümü')),
                        'income': Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Gelir')),
                        'expense': Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Gider')),
                      },
                      groupValue: _filterType,
                      onValueChanged: (v) =>
                          setState(() => _filterType = v),
                    ),
                  )
                ],
              ),
            ),

            // ▬▬ Özet ▬▬
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _summaryCard('Toplam Gelir', _sumIncome,
                      CupertinoColors.activeGreen),
                  const SizedBox(width: 12),
                  _summaryCard('Toplam Gider', _sumExpense,
                      CupertinoColors.destructiveRed),
                ],
              ),
            ),

            // ▬▬ Liste ▬▬
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('Henüz işlem yok'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final t = items[i];
                  return Container(
                    margin:
                    const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius:
                      BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          t.type == 'income'
                              ? CupertinoIcons
                              .arrow_down_circle
                              : CupertinoIcons
                              .arrow_up_circle,
                          color: t.type == 'income'
                              ? CupertinoColors
                              .activeGreen
                              : CupertinoColors
                              .destructiveRed,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.category,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(t.description),
                              const SizedBox(height: 6),
                              Text(
                                '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors
                                        .inactiveGray),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${t.type == 'income' ? '+' : '-'}${t.amount.toStringAsFixed(2)}₺',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.type == 'income'
                                ? CupertinoColors
                                .activeGreen
                                : CupertinoColors
                                .destructiveRed,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
