import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import 'import_models.dart';
import '../../core/network/backend_client.dart';
import '../../core/network/backend_cancellation.dart';

class ImportFailure implements Exception {
  const ImportFailure(this.code);
  final String code;
  String get message => importMessage(code);
}

String importMessage(String code) =>
    const {
      'SIMULATION_SNAPSHOT_CHANGED':
          'ข้อมูลพอร์ตเปลี่ยนแล้ว กรุณารีเฟรชข้อมูลก่อนจำลองใหม่',
      'SIMULATION_POSITION_NOT_FOUND':
          'ไม่พบสินทรัพย์นี้ กรุณารีเฟรชข้อมูลพอร์ต',
      'SIMULATION_POSITION_NOT_HELD':
          'สินทรัพย์นี้ไม่ได้อยู่ในสถานะถือครองแล้ว',
      'SIMULATION_DATE_BEFORE_SNAPSHOT':
          'วันที่ปัจจุบันอยู่ก่อนรายการซื้อขายล่าสุดที่นำเข้า กรุณาตรวจวันที่ในพอร์ต',
      'SIMULATION_QUANTITY_EXCEEDED':
          'จำนวนขายมากกว่าจำนวนที่ถืออยู่ กรุณาลดจำนวนและรีเฟรชข้อมูล',
      'SIMULATION_UNAVAILABLE': 'ระบบจำลองขายยังไม่พร้อม กรุณาติดต่อผู้ดูแล',
      'HISTORY_STORAGE_UNAVAILABLE':
          'ระบบประวัติยังไม่พร้อม กรุณาติดต่อผู้ดูแล',
      'ANALYTICS_STORAGE_UNAVAILABLE':
          'ระบบ Analytics ยังไม่พร้อม กรุณาติดต่อผู้ดูแล',
      'PDF_FILE_REQUIRED': 'กรุณาเลือกไฟล์ PDF',
      'INVALID_PDF': 'ไฟล์นี้ไม่ใช่ PDF ที่ถูกต้อง',
      'PDF_TOO_LARGE': 'ไฟล์ PDF ต้องมีขนาดไม่เกิน 10 MB',
      'PDF_PASSWORD_REQUIRED': 'ไฟล์นี้มีรหัสผ่าน กรุณากรอกรหัสเปิด PDF',
      'PASSWORD_REQUIRED': 'กรุณากรอกรหัสเปิด PDF ก่อนซิงค์',
      'PASSWORD_INVALID': 'รหัสเปิด PDF ไม่ถูกต้อง กรุณาลองใหม่',
      'PDF_PASSWORD_INVALID': 'รหัสเปิด PDF ไม่ถูกต้อง กรุณาลองใหม่',
      'INVALID_PDF_PASSWORD': 'รหัสเปิด PDF ต้องยาวไม่เกิน 128 ตัวอักษร',
      'PDF_TEXT_NOT_FOUND': 'ไม่พบข้อความใน PDF ไฟล์อาจเป็นภาพสแกน',
      'PDF_PARSE_FAILED': 'อ่าน PDF ไม่สำเร็จ หรือรูปแบบเอกสารยังไม่รองรับ',
      'PARSE_FAILED': 'อ่าน PDF ไม่สำเร็จ หรือรูปแบบเอกสารยังไม่รองรับ',
      'DIME_MONTHLY_TEMPORARILY_DISABLED':
          'ปิดการอ่าน Monthly ชั่วคราว กรุณาใช้ Confirmation',
      'DIME_DOCUMENT_UNSUPPORTED':
          'รองรับเฉพาะ Confirmation หุ้นนอก หุ้นไทย และกองทุนรวม',
      'NOT_DIME_CONFIRMATION': 'ไฟล์นี้ไม่ใช่ Dime Confirmation',
      'DIME_ORDERS_NOT_FOUND': 'ไม่พบรายการซื้อขายที่รองรับในเอกสาร',
      'UNAUTHORIZED': 'Session หมดอายุ กรุณาเข้าสู่ระบบใหม่',
      'MAIL_RECONNECT_REQUIRED': 'สิทธิ์ Gmail หมดอายุ กรุณาเชื่อมต่ออีเมลใหม่',
      'MAIL_NOT_CONNECTED': 'กรุณาเชื่อมต่อ Gmail ก่อนซิงค์',
      'MAIL_PROVIDER_UNSUPPORTED':
          'ขณะนี้รองรับ Gmail เท่านั้น กรุณาอัปโหลด PDF แทน',
      'MAIL_SYNC_BUSY': 'มีการซิงค์อยู่ กรุณารอคำขอเดิมเสร็จก่อน',
      'INVALID_MAIL_CURSOR':
          'ชุดข้อมูลหมดอายุหรือไม่ถูกต้อง กรุณาเริ่มซิงค์ใหม่',
      'INVALID_PAGINATION': 'โหลดชุดถัดไปไม่สำเร็จ กรุณาเริ่มซิงค์ใหม่',
      'GMAIL_RATE_LIMITED': 'เรียก Gmail บ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่',
      'GMAIL_ACCESS_DENIED':
          'อ่าน Gmail ไม่ได้ กรุณาตรวจสิทธิ์ Gmail กับผู้ดูแล',
      'GMAIL_UNAVAILABLE': 'Gmail ไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง',
      'GMAIL_REQUEST_FAILED': 'เรียกข้อมูล Gmail ไม่สำเร็จ กรุณาลองใหม่',
      'MAIL_OAUTH_STATE_INVALID': 'คำขออนุญาตหมดอายุ กรุณาเชื่อมต่อ Gmail ใหม่',
      'MAIL_CONSENT_DENIED': 'คุณยังไม่ได้อนุญาตให้อ่าน Gmail',
      'MAIL_CONNECTION_FAILED': 'เชื่อมต่อ Gmail ไม่สำเร็จ กรุณาเชื่อมต่อใหม่',
      'INVALID_MAIL_CLIENT':
          'รูปแบบการเชื่อมเมลไม่ถูกต้อง กรุณาอัปเดตแอปและ Backend',
      'MAIL_OAUTH_CODE_INVALID':
          'ยืนยันสิทธิ์ Gmail ไม่สำเร็จ กรุณาเชื่อมต่อใหม่',
      'MAIL_PERMISSION_REQUIRED': 'ต้องอนุญาตสิทธิ์อ่าน Gmail เพื่อซิงค์',
      'MAIL_EMAIL_MISMATCH': 'กรุณาเลือก Google บัญชีที่มีอีเมลตรงกับ Ruamport',
      'MAIL_CONFIG_MISSING': 'ระบบ Gmail ยังตั้งค่าไม่ครบ กรุณาติดต่อผู้ดูแล',
      'MAIL_STORAGE_UNAVAILABLE': 'ระบบจัดเก็บการเชื่อมต่ออีเมลยังไม่พร้อม',
      'MAIL_TOKEN_UNREADABLE':
          'ระบบอ่านข้อมูลเชื่อมต่ออีเมลไม่ได้ กรุณาติดต่อผู้ดูแล',
      'MAIL_READ_FAILED': 'อ่านอีเมลนี้ไม่สำเร็จ',
      'LIMIT_SKIPPED': 'ไฟล์นี้ยังอ่านไม่ได้เนื่องจากเกินขอบเขตที่ระบบรองรับ',
      'INVESTMENT_STORAGE_UNAVAILABLE':
          'ระบบจัดเก็บข้อมูลลงทุนยังไม่พร้อม กรุณาติดต่อผู้ดูแล',
      'DOCUMENT_NOT_FOUND': 'ไม่พบเอกสาร หรือคุณไม่มีสิทธิ์เข้าถึง',
      'NETWORK': 'เชื่อมต่อ Backend ไม่สำเร็จ กรุณาลองใหม่',
      'BACKEND_NOT_READY': 'เชื่อมต่อระบบไม่ได้ กรุณาลองใหม่',
      'REQUEST_CANCELLED': 'คำขอถูกยกเลิก',
      'TIMEOUT': 'ใช้เวลานานเกินกำหนด กรุณาลองใหม่ ผลบางส่วนอาจบันทึกแล้ว',
      'INVALID_RESPONSE': 'Backend ตอบข้อมูลไม่ครบ กรุณาลองใหม่',
      'ACCOUNT_CHANGED': 'บัญชีผู้ใช้เปลี่ยนไป กรุณาเริ่มใหม่',
    }[code] ??
    'ดำเนินการไม่สำเร็จ กรุณาลองใหม่หรือติดต่อผู้ดูแล';

class ImportApi {
  ImportApi({
    required this.tokenProvider,
    this.onUnauthorized,
    http.Client? client,
    String? apiUrl,
    BackendClient? backend,
    this.accountCancellation,
    bool checkReadiness = true,
  }) : _backend =
           backend ??
           BackendClient(
             apiUrl: apiUrl ?? AppConfig.apiUrl,
             healthUrl: apiUrl == null ? AppConfig.healthUrl : null,
             client: client,
             checkReadiness: checkReadiness,
           ),
       _ownsBackend = backend == null,
       _apiUrl = backend?.api.toString() ?? apiUrl ?? AppConfig.apiUrl;
  factory ImportApi.forAuth(AuthController auth) {
    final accountId = auth.user?.id;
    return ImportApi(
      tokenProvider: () async {
        if (accountId == null || auth.user?.id != accountId) {
          throw const ImportFailure('ACCOUNT_CHANGED');
        }
        return auth.tokenForApi();
      },
      onUnauthorized: auth.logout,
      backend: auth.backend,
      accountCancellation: auth.sessionRequests,
    );
  }
  final Future<String> Function() tokenProvider;
  final Future<void> Function()? onUnauthorized;
  final BackendClient _backend;
  final bool _ownsBackend;
  final BackendCancellation? accountCancellation;
  final _lifetime = BackendCancellation();
  final String _apiUrl;
  Uri _uri(String path) =>
      Uri.parse('${_apiUrl.replaceFirst(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri,
    BackendRequestFactory createRequest, {
    Duration timeout = const Duration(seconds: 30),
    BackendCancellation? cancel,
  }) async {
    try {
      final response = await _backend.send(
        method: method,
        uri: uri,
        createRequest: createRequest,
        timeout: timeout,
        tokenProvider: tokenProvider,
        cancel: [_lifetime, accountCancellation, cancel],
      );
      final data = objectMap(jsonDecode(response.body));
      if (response.statusCode >= 400) {
        final code = textValue(objectMap(data['error'])['code']) ?? 'UNKNOWN';
        // Gmail 401 MAIL_RECONNECT_REQUIRED ต้องเชื่อมเมลใหม่ ไม่ Logout Ruamport
        if (response.statusCode == 401 && code == 'UNAUTHORIZED') {
          await onUnauthorized?.call();
        }
        throw ImportFailure(code);
      }
      if (data.isEmpty) throw const ImportFailure('INVALID_RESPONSE');
      return data;
    } on BackendNotReady {
      throw const ImportFailure('BACKEND_NOT_READY');
    } on BackendCancelled {
      throw const ImportFailure('REQUEST_CANCELLED');
    } on TimeoutException {
      throw const ImportFailure('TIMEOUT');
    } on http.ClientException {
      throw const ImportFailure('NETWORK');
    } on FormatException {
      throw const ImportFailure('INVALID_RESPONSE');
    } on LoginFailure {
      throw const ImportFailure('UNAUTHORIZED');
    }
  }

  Future<Map<String, dynamic>> jsonRequest(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
    BackendCancellation? cancel,
  }) {
    final uri = _uri(path);
    return _send(
      method,
      uri,
      (abort) {
        final request = http.AbortableRequest(method, uri, abortTrigger: abort);
        if (body != null) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        return request;
      },
      timeout: timeout,
      cancel: cancel,
    );
  }

  Future<PdfPreview> upload(SelectedPdf file, String password) async {
    if (!file.name.toLowerCase().endsWith('.pdf') || file.bytes.isEmpty) {
      throw const ImportFailure('PDF_FILE_REQUIRED');
    }
    if (file.bytes.length > SelectedPdf.maxBytes) {
      throw const ImportFailure('PDF_TOO_LARGE');
    }
    if (password.length > 128) {
      throw const ImportFailure('INVALID_PDF_PASSWORD');
    }
    final uri = _uri('/trades/upload-preview');
    return checkedPreview(
      await _send('POST', uri, (abort) {
        final request = http.AbortableMultipartRequest(
          'POST',
          uri,
          abortTrigger: abort,
        );
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes,
            filename: file.name,
            contentType: MediaType('application', 'pdf'),
          ),
        );
        if (password.isNotEmpty) request.fields['pdfPassword'] = password;
        return request;
      }, timeout: const Duration(seconds: 180)),
    );
  }

  PdfPreview checkedPreview(Map<String, dynamic> data) {
    final preview = PdfPreview(data);
    if (!preview.supported) {
      throw ImportFailure(
        preview.type == 'DIME_MONTHLY_STATEMENT'
            ? 'DIME_MONTHLY_TEMPORARILY_DISABLED'
            : 'DIME_DOCUMENT_UNSUPPORTED',
      );
    }
    return preview;
  }

  Future<PdfPreview> document(String id) async => checkedPreview(
    await jsonRequest('/trades/documents/${Uri.encodeComponent(id)}'),
  );
  Future<Map<String, dynamic>> connection() => jsonRequest('/mail/connection');
  Future<Map<String, dynamic>> connect() => jsonRequest(
    '/mail/gmail/connect',
    method: 'POST',
    body: {'client': kIsWeb ? 'web' : 'mobile'},
  );
  Future<Map<String, dynamic>> disconnect() =>
      jsonRequest('/mail/gmail/connection', method: 'DELETE');
  Future<MailBatch> sync(
    Object months,
    String password, [
    String? cursor,
  ]) async => MailBatch.fromJson(
    await jsonRequest(
      '/mail/gmail/sync-preview',
      method: 'POST',
      body: {'months': months, 'pdfPassword': password, 'cursor': ?cursor},
      timeout: const Duration(seconds: 180),
    ),
  );
  Future<Map<String, dynamic>> save(List<String> ids) => jsonRequest(
    '/trades/import',
    method: 'POST',
    body: {'documentIds': ids},
    timeout: const Duration(seconds: 180),
  );
  void dispose() {
    _lifetime.cancel();
    if (_ownsBackend) _backend.dispose();
  }
}
