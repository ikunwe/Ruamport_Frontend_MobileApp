import 'package:flutter/foundation.dart';
import 'import_api.dart';
import 'import_models.dart';

class ImportController extends ChangeNotifier {
  ImportController(this.api, {required this.mail});
  final ImportApi api;
  final bool mail;
  bool busy = false, loadingConnection = false, scanning = false;
  bool stopRequested = false, stopped = false, needsReconnect = false;
  bool _disposed = false;
  Object months = 'all';
  SelectedPdf? file;
  PdfPreview? preview;
  Map<String, dynamic>? connection;
  Map<String, dynamic> progress = {};
  final batches = <MailBatch>[];
  final records = <String, DocumentRecord>{};
  final importResults = <Map<String, dynamic>>[];
  int selectedBatchIndex = 0, _progressIndex = -1;
  String? error, message;
  MailBatch? get selectedBatch =>
      batches.isEmpty ? null : batches[selectedBatchIndex];
  DocumentRecord record(DocumentRecord original) =>
      records[original.id] ?? original;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _remember(DocumentRecord value) {
    final id = value.id;
    if (id != null && records[id]?.imported != true) records[id] = value;
  }

  void _clearResults() {
    preview = null;
    batches.clear();
    records.clear();
    importResults.clear();
    selectedBatchIndex = 0;
    progress = {};
    _progressIndex = -1;
    error = null;
    message = null;
    stopped = false;
  }

  void selectFile(SelectedPdf value) {
    if (busy) return;
    _clearResults();
    file = value;
    _emit();
  }

  void setMonths(Object value) {
    if (busy || !['all', 1, 2].contains(value)) return;
    months = value;
    _clearResults();
    _emit();
  }

  void selectBatch(int index) {
    if (index < 0 || index >= batches.length) return;
    selectedBatchIndex = index;
    preview = null;
    _emit();
  }

  void closePreview() {
    preview = null;
    _emit();
  }

  void stop() {
    if (scanning) {
      stopRequested = true;
      _emit();
    }
  }

  void showError(Object failure) {
    error = failure is ImportFailure
        ? failure.message
        : 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่';
    if (failure is ImportFailure &&
        [
          'MAIL_RECONNECT_REQUIRED',
          'MAIL_NOT_CONNECTED',
        ].contains(failure.code)) {
      needsReconnect = true;
    }
    _emit();
  }

  Future<void> loadConnection({String? callbackCode}) async {
    if (busy || loadingConnection) return;
    loadingConnection = true;
    error = null;
    _emit();
    try {
      final value = await api.connection();
      if (_disposed) return;
      connection = value;
      needsReconnect = false;
      if (callbackCode != null) error = importMessage(callbackCode);
    } catch (failure) {
      if (!_disposed) showError(failure);
    } finally {
      loadingConnection = false;
      _emit();
    }
  }

  Future<Uri?> connect() async {
    if (busy || connection?['supported'] != true) return null;
    busy = true;
    error = null;
    _emit();
    try {
      final data = await api.connect();
      if (_disposed) return null;
      final url = Uri.tryParse(textValue(data['authorizationUrl']) ?? '');
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'accounts.google.com' ||
          url.userInfo.isNotEmpty ||
          url.port != 443) {
        throw const ImportFailure('INVALID_RESPONSE');
      }
      return url;
    } catch (failure) {
      if (!_disposed) showError(failure);
      return null;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    error = null;
    _emit();
    try {
      final data = await api.disconnect();
      if (_disposed) return;
      _clearResults();
      connection = {...?connection, 'connected': false, 'connection': null};
      needsReconnect = false;
      message = data['googleRevoked'] == true
          ? 'ตัดการเชื่อมต่ออีเมลแล้ว'
          : 'ลบการเชื่อมต่อแล้ว คุณสามารถตรวจสิทธิ์แอปเพิ่มเติมใน Google Account';
    } catch (failure) {
      if (!_disposed) showError(failure);
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> upload(String password) async {
    if (busy || file == null) return;
    if (password.length > 128) {
      showError(const ImportFailure('INVALID_PDF_PASSWORD'));
      return;
    }
    busy = true;
    preview = null;
    error = null;
    message = null;
    importResults.clear();
    _emit();
    try {
      final result = await api.upload(file!, password);
      if (_disposed) return;
      preview = result;
      _remember(result.record);
    } catch (failure) {
      if (!_disposed) showError(failure);
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> sync(String password, {int? retryIndex}) async {
    if (busy ||
        loadingConnection ||
        connection?['connected'] != true ||
        connection?['supported'] != true ||
        needsReconnect) {
      return;
    }
    if (password.trim().isEmpty) {
      showError(const ImportFailure('PASSWORD_REQUIRED'));
      return;
    }
    if (password.length > 128) {
      showError(const ImportFailure('INVALID_PDF_PASSWORD'));
      return;
    }
    final retry = retryIndex != null;
    if (retry && (retryIndex < 0 || retryIndex >= batches.length)) return;
    final old = retry ? batches[retryIndex] : null;
    String? cursor = old?.retryCursor;
    if (retry && cursor == null) {
      showError(const ImportFailure('INVALID_MAIL_CURSOR'));
      return;
    }
    final range = old?.months ?? months;
    if (!retry) _clearResults();
    busy = true;
    scanning = !retry;
    stopRequested = false;
    stopped = false;
    error = null;
    message = null;
    _emit();
    int index = retryIndex ?? 0;
    final seen = <String>{};
    try {
      while (true) {
        if (cursor != null) seen.add(cursor);
        final result = await api.sync(range, password, cursor);
        if (_disposed) return;
        for (final item in result.files) {
          _remember(item.record);
        }
        if (retry) {
          batches[index] = batches[index].mergeRetry(result);
        } else {
          batches.add(result);
        }
        if (index >= _progressIndex) {
          progress = result.progress;
          _progressIndex = index;
        }
        _emit();
        if (retry || !result.hasMore || stopRequested) {
          stopped = stopRequested && result.hasMore;
          message = stopped
              ? 'หยุดโหลดเพิ่มเติมแล้ว รายการที่อ่านได้ยังดูได้'
              : retry
              ? 'อ่านชุดเดิมด้วยรหัสใหม่แล้ว'
              : result.data['noNewData'] == true
              ? 'ไม่พบ Confirmation ใหม่'
              : result.data['syncStatus'] == 'COMPLETED_WITH_ERRORS'
              ? 'ตรวจครบแล้ว แต่มีบางไฟล์ที่ยังอ่านไม่ได้'
              : 'ซิงค์ครบช่วงเวลาที่เลือกแล้ว';
          break;
        }
        if (result.nextCursor == null || seen.contains(result.nextCursor)) {
          throw const ImportFailure('INVALID_PAGINATION');
        }
        cursor = result.nextCursor;
        index++;
      }
    } catch (failure) {
      if (!_disposed) showError(failure);
    } finally {
      password = ''; // ใช้รหัสเฉพาะรอบนี้ ไม่เก็บใน state ถาวร
      busy = false;
      scanning = false;
      _emit();
    }
  }

  Future<void> view(MailFile item) async {
    if (busy || !item.successful) return;
    if (item.preview?.supported == true) {
      preview = item.preview;
      _remember(preview!.record);
      _emit();
      return;
    }
    if (item.record.id == null) return;
    busy = true;
    error = null;
    _emit();
    try {
      final result = await api.document(item.record.id!);
      if (_disposed) return;
      preview = result;
      _remember(result.record);
    } catch (failure) {
      if (!_disposed) showError(failure);
    } finally {
      busy = false;
      _emit();
    }
  }

  List<String> get importableIds {
    final ids = <String>{};
    void include(DocumentRecord value, {bool blocked = false}) {
      final latest = record(value);
      if (latest.canImport && !blocked) ids.add(latest.id!);
    }

    if (!mail && preview != null) {
      include(preview!.record, blocked: preview!.blocksImport);
    }
    if (mail) {
      for (final file in batches.expand((batch) => batch.files)) {
        if (file.old || file.preview?.supported == true) {
          include(file.record, blocked: file.preview?.blocksImport == true);
        }
      }
    }
    return ids.toList();
  }

  bool get canSavePreview =>
      preview?.supported == true &&
      !preview!.blocksImport &&
      record(preview!.record).canImport;

  String documentName(Object? id) {
    if (preview?.record.id == id) return preview!.filename;
    for (final file in batches.expand((batch) => batch.files)) {
      if (file.record.id == id) return file.filename;
    }
    return 'เอกสาร';
  }

  Future<void> save({bool currentOnly = false}) async {
    if (busy) return;
    final ids = currentOnly
        ? (canSavePreview ? [record(preview!.record).id!] : <String>[])
        : importableIds;
    if (ids.isEmpty) return;
    busy = true;
    error = null;
    message = null;
    importResults.clear();
    _emit();
    try {
      for (int offset = 0; offset < ids.length; offset += 50) {
        final group = ids.skip(offset).take(50).toList();
        final data = await api.save(group);
        if (_disposed) return;
        final results = {
          for (final item in objectList(data['results']))
            item['documentId']: item,
        };
        for (final id in group) {
          final result =
              results[id] ?? {'documentId': id, 'outcome': 'UNCONFIRMED'};
          importResults.add(result);
          if (['IMPORTED', 'ALREADY_IMPORTED'].contains(result['outcome'])) {
            records[id] = (records[id] ?? DocumentRecord({'id': id}))
                .asImported();
          }
        }
        _emit();
      }
    } catch (failure) {
      if (!_disposed) showError(failure);
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    file = null;
    preview = null;
    batches.clear();
    records.clear();
    importResults.clear();
    api.dispose();
    super.dispose();
  }
}
