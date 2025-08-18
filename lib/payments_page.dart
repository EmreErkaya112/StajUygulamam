// lib/payments_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Tek bir ödeme kaydı
class Payment {
  final double amount;
  final DateTime paymentDate;

  /// Opsiyonel periyot alanları (API verirse doldururuz)
  final int? periodValue;      // örn: 1, 2, 3
  final String? periodUnit;    // 'day' | 'week' | 'month' | 'year'
  final DateTime? nextDueDate; // API doğrudan gönderirse

  Payment({
    required this.amount,
    required this.paymentDate,
    this.periodValue,
    this.periodUnit,
    this.nextDueDate,
  });

  factory Payment.fromJson(Map<String, dynamic> j) {
    // amount
    final rawAmt = j['amount'];
    final amt = rawAmt is num ? rawAmt.toDouble() : double.tryParse('${rawAmt ?? 0}') ?? 0.0;

    // date
    final String dateStr = (j['payment_date'] as String).trim();
    final DateTime pDate = DateTime.parse(dateStr);

    // period (hem snake_case hem camelCase destekleyelim)
    int? pv;
    String? pu;
    DateTime? nd;

    // period_value
    if (j.containsKey('period_value')) {
      final v = j['period_value'];
      pv = v is num ? v.toInt() : int.tryParse('$v');
    } else if (j.containsKey('periodValue')) {
      final v = j['periodValue'];
      pv = v is num ? v.toInt() : int.tryParse('$v');
    }

    // period_unit
    if (j.containsKey('period_unit')) {
      pu = (j['period_unit'] as String?)?.toLowerCase();
    } else if (j.containsKey('periodUnit')) {
      pu = (j['periodUnit'] as String?)?.toLowerCase();
    }

    // next_due_date
    final ndRaw = j['next_due_date'] ?? j['nextDueDate'];
    if (ndRaw is String && ndRaw.trim().isNotEmpty) {
      nd = DateTime.tryParse(ndRaw.trim());
    }

    return Payment(
      amount: amt,
      paymentDate: pDate,
      periodValue: pv,
      periodUnit: pu,
      nextDueDate: nd,
    );
  }
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({Key? key}) : super(key: key);

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  bool _loading = true;
  String? _error;
  List<Payment> _payments = [];

  // IBAN & hesap sahibi (statik metin)
  final String _iban = 'TR53 0004 6005 8488 8000 1945 41';
  final String _accountHolder = 'TOKAT İLİ YAĞMURLU KASABASI KÜLTÜR VE DAYANIŞMA DERNEĞİ';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId');
      if (uid == null) throw 'Kullanıcı ID bulunamadı';

      final url = Uri.parse(
        // API’nin adı sende böyleydi; veri şekli Payment.fromJson ile uyumlu olmalı
        'https://erkayasoft.com/api/get_payment_history.php?user_id=$uid',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) {
        throw 'Sunucu hatası: ${res.statusCode}';
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw body['error'] ?? 'API’den success=false döndü';
      }

      final list = (body['data'] as List)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();

      // yeni -> eski
      list.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

      setState(() {
        _payments = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // ——— Yardımcılar ———

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _copyIban() {
    Clipboard.setData(ClipboardData(text: _iban));
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('IBAN kopyalandı'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Tamam'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Tarihe periyot ekleme (admin paneldekiyle uyumlu)
  DateTime _addPeriod(DateTime base, int pv, String unit) {
    switch (unit) {
      case 'day':
        return base.add(Duration(days: pv));
      case 'week':
        return base.add(Duration(days: pv * 7));
      case 'year':
        return DateTime(base.year + pv, base.month, base.day);
      case 'month':
      default:
        return DateTime(base.year, base.month + pv, base.day);
    }
  }

  /// Son kayda göre due hesapla: (API verirse kullan, yoksa yerel hesap)
  DateTime? _computeNextDue() {
    if (_payments.isEmpty) return null;
    final last = _payments.first;
    if (last.nextDueDate != null) return last.nextDueDate;
    // period bilgisi yoksa varsayılan 1 ay
    final pv = last.periodValue ?? 1;
    final pu = (last.periodUnit ?? 'month').toLowerCase();
    return _addPeriod(last.paymentDate, pv, pu);
  }

  String _prettyUnitTR(String? unit, int? pv) {
    final u = (unit ?? 'month').toLowerCase();
    final n = pv ?? 1;
    switch (u) {
      case 'day':   return '$n gün';
      case 'week':  return '$n hafta';
      case 'year':  return '$n yıl';
      case 'month':
      default:      return '$n ay';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final lastDate = _payments.isNotEmpty ? _payments.first.paymentDate : null;
    final dueDate  = _computeNextDue();

    final int? daysUntilDue = (dueDate != null)
        ? dueDate.difference(DateTime(now.year, now.month, now.day)).inDays
        : null;

    final bool overdue = (daysUntilDue != null) ? daysUntilDue < 0 : false;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Ödeme Geçmişi'),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : _error != null
            ? Center(child: Text('Hata: $_error'))
            : CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    // IBAN Kartı
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            CupertinoColors.activeBlue,
                            CupertinoColors.systemBlue
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'IBAN',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _iban,
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _copyIban,
                                child: const Icon(
                                  CupertinoIcons.doc_on_doc,
                                  color: CupertinoColors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Hesap Sahibi',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _accountHolder,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Ödeme Durumu Kartı
                    if (lastDate != null && dueDate != null)
                      Container(
                        decoration: BoxDecoration(
                          color: overdue
                              ? CupertinoColors.systemRed.withOpacity(0.15)
                              : CupertinoColors.activeGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              overdue
                                  ? CupertinoIcons.exclamationmark_triangle_fill
                                  : CupertinoIcons.clock_fill,
                              color: overdue
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.activeGreen,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Son Ödeme: ${_formatDate(lastDate)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Sonraki Ödeme: ${_formatDate(dueDate)}',
                                    style: const TextStyle(
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    (daysUntilDue == null)
                                        ? '-'
                                        : (overdue
                                        ? 'Gecikti: ${-daysUntilDue} gün'
                                        : '$daysUntilDue gün kaldı'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: overdue
                                          ? CupertinoColors.systemRed
                                          : CupertinoColors.activeGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Liste başlığı
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Ödeme Listesi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Ödeme listesi
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: _payments.isEmpty
                  ? const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Henüz ödeme yok')),
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final p = _payments[i];

                    // Periyot yazısı (varsa)
                    final periyot =
                    _prettyUnitTR(p.periodUnit, p.periodValue);

                    // Kayıt bazlı nextDue (liste öğesinde opsiyonel gösterim)
                    final DateTime? rowNextDue =
                        p.nextDueDate ??
                            ((p.periodValue != null && p.periodUnit != null)
                                ? _addPeriod(p.paymentDate, p.periodValue!, p.periodUnit!)
                                : null);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.creditcard_fill,
                                  color: CupertinoColors.activeBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _formatDate(p.paymentDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '+${p.amount.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: CupertinoColors.activeGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.timer,
                                  size: 16,
                                  color: CupertinoColors.inactiveGray,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Periyot: $periyot',
                                  style: const TextStyle(
                                    color: CupertinoColors.inactiveGray,
                                    fontSize: 13,
                                  ),
                                ),
                                if (rowNextDue != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(
                                    CupertinoIcons.calendar,
                                    size: 16,
                                    color: CupertinoColors.inactiveGray,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sonraki: ${_formatDate(rowNextDue)}',
                                    style: const TextStyle(
                                      color: CupertinoColors.inactiveGray,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _payments.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
