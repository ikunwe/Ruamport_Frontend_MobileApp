import 'dart:typed_data';

Map<String, dynamic> objectMap(Object? value) =>
    value is Map<String, dynamic> ? value : {};
List<Map<String, dynamic>> objectList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
String? textValue(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

class SelectedPdf {
  const SelectedPdf({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  static const maxBytes = 10 * 1024 * 1024;
}

class DocumentRecord {
  const DocumentRecord(this.data);
  final Map<String, dynamic> data;
  String? get id => textValue(data['id']);
  bool get imported => data['status'] == 'IMPORTED';
  bool get canImport =>
      id != null && data['status'] == 'PREVIEW' && data['canImport'] == true;
  factory DocumentRecord.fromJson(Object? value) =>
      DocumentRecord(objectMap(value));
  DocumentRecord asImported() =>
      DocumentRecord({...data, 'status': 'IMPORTED', 'canImport': false});
}

class PdfPreview {
  const PdfPreview(this.data);
  final Map<String, dynamic> data;
  Map<String, dynamic> get document => objectMap(data['document']);
  String get type => textValue(document['type']) ?? '';
  static const types = [
    'DIME_OFFSHORE_CONFIRMATION_NOTE',
    'DIME_THAI_STOCK_CONFIRMATION_NOTE',
    'DIME_MUTUAL_FUND_CONFIRMATION_NOTE',
  ];
  bool get supported => types.contains(type);
  bool get offshore => type == types[0];
  bool get fund => type == types[2];
  String get assetLabel => offshore
      ? 'หุ้นนอก'
      : fund
      ? 'กองทุนรวม'
      : 'หุ้นไทย';
  String get filename =>
      textValue(objectMap(data['file'])['name']) ?? 'เอกสาร PDF';
  String get documentNumber => textValue(document['documentNumber']) ?? '—';
  DocumentRecord get record => DocumentRecord.fromJson(data['record']);
  List<Map<String, dynamic>> get orders => objectList(data['orders']);
  Map<String, dynamic> get validation => objectMap(data['validation']);
  List<Map<String, dynamic>> get warnings => objectList(validation['warnings']);
  bool get blocksImport => validation['blocksImport'] == true;
  // ห้ามใช้ calculation หรือ summary แทน display ของหุ้นนอกเมื่อยอดอ่านไม่ได้
  Map<String, dynamic> get totals =>
      objectMap(data[offshore ? 'display' : 'summary']);
}

class MailFile {
  const MailFile(this.data);
  final Map<String, dynamic> data;
  String get status => textValue(data['status']) ?? 'PARSE_FAILED';
  Map<String, dynamic> get source => objectMap(data['source']);
  String get identity =>
      '${source['messageId']}|${source['attachmentId'] ?? source['partId'] ?? 'message'}';
  String get filename => textValue(source['filename']) ?? 'ไฟล์แนบ PDF';
  String get errorCode => textValue(objectMap(data['error'])['code']) ?? status;
  bool get successful =>
      ['READY', 'ALREADY_READ', 'ALREADY_IMPORTED'].contains(status);
  bool get old => status == 'ALREADY_READ' || status == 'ALREADY_IMPORTED';
  bool get locked =>
      status == 'PASSWORD_REQUIRED' || status == 'PASSWORD_INVALID';
  DocumentRecord get record => DocumentRecord.fromJson(
    data['record'] ?? objectMap(data['preview'])['record'],
  );
  PdfPreview? get preview =>
      status == 'READY' && data['preview'] is Map<String, dynamic>
      ? PdfPreview({
          ...data['preview'] as Map<String, dynamic>,
          if (data['record'] is Map<String, dynamic>) 'record': data['record'],
        })
      : null;
  bool get visible =>
      objectMap(objectMap(data['preview'])['document'])['type'] !=
          'DIME_MONTHLY_STATEMENT' &&
      errorCode != 'DIME_MONTHLY_TEMPORARILY_DISABLED';
}

class MailBatch {
  const MailBatch({required this.data, required this.files});
  factory MailBatch.fromJson(Map<String, dynamic> data) {
    final unique = <String, MailFile>{};
    for (final row in objectList(data['results'])) {
      final file = MailFile(row);
      if (!file.visible) continue;
      if (!unique.containsKey(file.identity) || file.successful) {
        unique[file.identity] = file;
      }
    }
    return MailBatch(data: data, files: unique.values.toList());
  }
  final Map<String, dynamic> data;
  final List<MailFile> files;
  Object get months => data['months'] ?? 'all';
  bool get hasMore => data['hasMore'] == true;
  String? get nextCursor => textValue(data['nextCursor']);
  String? get retryCursor => textValue(data['retryCursor']);
  Map<String, dynamic> get progress => objectMap(data['progress']);
  MailBatch mergeRetry(MailBatch next) {
    final successful = {
      for (final file in files.where((file) => file.successful))
        file.identity: file,
    };
    return MailBatch(
      data: next.data,
      files: next.files
          .map(
            (file) =>
                file.successful ? file : successful[file.identity] ?? file,
          )
          .toList(),
    );
  }
}
