import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../import/import_api.dart';
import '../import/import_models.dart';
import 'portfolio_data.dart';

class PortfolioStore extends ChangeNotifier {
  PortfolioStore(this.api);
  final ImportApi api;
  HoldingsData? data;
  String? error;
  bool loading = false, thb = false, _disposed = false, _active = true;
  String? selectedKey;
  Timer? _timer;
  DateTime? _due;
  final _cache = <String, (DateTime, Map<String, dynamic>)>{};
  final _pending = <String, Future<Map<String, dynamic>>>{};
  int _revision = 0;
  int get revision => _revision;
  String? _financialSignature;
  bool _refreshAgain = false;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void currency(bool value) {
    thb = value;
    _emit();
  }

  void active(bool value) {
    _active = value;
    _timer?.cancel();
    if (value && _due != null) {
      if (_due!.isBefore(DateTime.now())) {
        unawaited(refresh());
      } else {
        _schedule();
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_active && _due != null && !_disposed) {
      _timer = Timer(
        _due!.difference(DateTime.now()),
        () => unawaited(refresh()),
      );
    }
  }

  Future<void> refresh({bool afterImport = false}) async {
    if (_disposed) return;
    if (loading) {
      if (afterImport) _refreshAgain = true;
      return;
    }
    loading = true;
    error = null;
    _timer?.cancel();
    _emit();
    try {
      final response = await api.jsonRequest(
        '/trades/holdings?includeClosed=true&includeFx=true&includeMarket=true&includeLogos=true',
        timeout: const Duration(seconds: 90),
      );
      if (_disposed) return;
      if (response['items'] is! List || response['includeClosed'] != true) {
        throw const ImportFailure('INVALID_RESPONSE');
      }
      data = HoldingsData(response);
      final signature = jsonEncode(
        data!.items
            .map(
              (item) => [
                item.key,
                item.data['quantity'],
                item.data['status'],
                item.data['transactionCount'],
                item.data['costBasis'],
                item.data['amounts'],
                item.data['realizedPnl'],
              ],
            )
            .toList(),
      );
      if (signature != _financialSignature) {
        _financialSignature = signature;
        _revision++;
        _cache.clear();
        _pending.clear();
      }
      // ขอ Backend เมื่อ snapshot ราคา/โลโก้หมดอายุ ไม่เรียก Finnhub จาก Flutter
      final now = DateTime.now();
      final times = <DateTime>[];
      for (final item in data!.items) {
        for (final part in [item.quote, objectMap(item.data['logo'])]) {
          final next = DateTime.tryParse(
            textValue(part['retryAt'] ?? part['expiresAt']) ?? '',
          );
          if (next != null && next.isAfter(now)) times.add(next);
        }
      }
      final fxNext = DateTime.tryParse(
        textValue(objectMap(response['fx'])['expiresAt']) ?? '',
      );
      if (fxNext != null && fxNext.isAfter(now)) times.add(fxNext);
      times.sort();
      final delay = times.isEmpty
          ? const Duration(minutes: 5)
          : times.first.difference(now);
      _due = now.add(
        delay < const Duration(minutes: 1) ? const Duration(minutes: 1) : delay,
      );
    } catch (failure) {
      if (!_disposed) {
        error = failure is ImportFailure
            ? failure.message
            : 'โหลดข้อมูลพอร์ตไม่สำเร็จ กรุณาลองใหม่';
      }
      _due = DateTime.now().add(const Duration(minutes: 5));
    } finally {
      loading = false;
      _emit();
      _schedule();
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  Future<Map<String, dynamic>> request(String path, {bool force = false}) {
    final cached = _cache[path];
    if (!force && cached != null && cached.$1.isAfter(DateTime.now())) {
      return Future.value(cached.$2);
    }
    if (_pending[path] != null) return _pending[path]!;
    final revision = _revision;
    late final Future<Map<String, dynamic>> future;
    future = api
        .jsonRequest(path, timeout: const Duration(seconds: 180))
        .then((value) {
          if (_disposed || revision != _revision) {
            throw const ImportFailure('ACCOUNT_CHANGED');
          }
          final expires = DateTime.tryParse(
            textValue(objectMap(value['cache'])['expiresAt']) ?? '',
          );
          _cache[path] = (
            expires != null && expires.isAfter(DateTime.now())
                ? expires
                : DateTime.now().add(const Duration(minutes: 5)),
            value,
          );
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[path], future)) _pending.remove(path);
        });
    _pending[path] = future;
    return future;
  }

  Future<List<Map<String, dynamic>>> pages(String path) async {
    final rows = <String, Map<String, dynamic>>{};
    int offset = 0;
    while (true) {
      final page = await request('$path?offset=$offset&limit=100');
      if (page['items'] is! List) throw const ImportFailure('INVALID_RESPONSE');
      for (final row in objectList(page['items'])) {
        final id = textValue(row['id']);
        if (id != null) rows[id] = row;
      }
      if (page['hasMore'] != true) return rows.values.toList();
      final next = page['nextOffset'];
      if (next is! int || next <= offset) {
        throw const ImportFailure('INVALID_PAGINATION');
      }
      offset = next;
    }
  }

  Future<List<Map<String, dynamic>>> transactions(Holding holding) async {
    final result = await Future.wait([
      pages('/trades/documents'),
      pages('/trades/transactions'),
    ]);
    final docs = {
      for (final doc in result[0].where((doc) => doc['status'] == 'IMPORTED'))
        doc['id']: doc,
    };
    const types = {
      'DIME_OFFSHORE_CONFIRMATION_NOTE': 'OFFSHORE_STOCK',
      'DIME_THAI_STOCK_CONFIRMATION_NOTE': 'THAI_STOCK',
      'DIME_MUTUAL_FUND_CONFIRMATION_NOTE': 'MUTUAL_FUND',
    };
    return result[1].where((row) {
      final doc = objectMap(docs[row['document_id']]?['document']);
      final type = types[doc['type']];
      if (row['is_duplicate'] == true || type == null) return false;
      return type == holding.type &&
          doc['accountNumber'] == holding.data['accountNumber'] &&
          row['asset_name'] == holding.symbol &&
          row['currency'] == holding.currency &&
          (type == 'MUTUAL_FUND'
                  ? null
                  : textValue(objectMap(row['details'])['exchange'])) ==
              textValue(holding.data['exchange']);
    }).toList()..sort(
      (a, b) => (textValue(b['trade_date']) ?? '').compareTo(
        textValue(a['trade_date']) ?? '',
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _cache.clear();
    _pending.clear();
    api.dispose();
    super.dispose();
  }
}
