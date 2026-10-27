import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';
import 'import_api.dart';
import 'import_controller.dart';
import 'import_models.dart';
import 'pdf_preview_view.dart';

class InvestmentImportSheet extends StatefulWidget {
  const InvestmentImportSheet({
    super.key,
    required this.mail,
    required this.api,
    this.callbackCode,
    this.pickPdf,
    this.onSaved,
  });
  final bool mail;
  final ImportApi api;
  final String? callbackCode;
  final Future<SelectedPdf?> Function()? pickPdf;
  final VoidCallback? onSaved;
  @override
  State<InvestmentImportSheet> createState() => _InvestmentImportSheetState();
}

class _InvestmentImportSheetState extends State<InvestmentImportSheet> {
  late final ImportController controller;
  final password = TextEditingController();
  bool picking = false, confirmDisconnect = false;
  final reportedImports = <String>{};
  @override
  void initState() {
    super.initState();
    controller = ImportController(widget.api, mail: widget.mail)
      ..addListener(changed);
    if (widget.mail) {
      unawaited(controller.loadConnection(callbackCode: widget.callbackCode));
    }
  }

  void changed() {
    if (!controller.busy) {
      final ids = controller.importResults
          .where(
            (row) => ['IMPORTED', 'ALREADY_IMPORTED'].contains(row['outcome']),
          )
          .map((row) => row['documentId'])
          .whereType<String>()
          .toSet();
      if (ids.difference(reportedImports).isNotEmpty) {
        reportedImports.addAll(ids);
        widget.onSaved?.call();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    password.dispose();
    controller.removeListener(changed);
    controller.dispose();
    super.dispose();
  }

  Future<void> choosePdf() async {
    if (controller.busy || picking) return;
    setState(() => picking = true);
    password.clear();
    try {
      SelectedPdf? file;
      if (widget.pickPdf != null) {
        file = await widget.pickPdf!();
      } else {
        final value = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (value == null) return;
        final size = await value.length();
        if (size == null) throw const ImportFailure('PDF_FILE_REQUIRED');
        if (size > SelectedPdf.maxBytes) {
          throw const ImportFailure('PDF_TOO_LARGE');
        }
        file = SelectedPdf(name: value.name, bytes: await value.readAsBytes());
      }
      if (!mounted || file == null) return;
      if (!file.name.toLowerCase().endsWith('.pdf') || file.bytes.isEmpty) {
        throw const ImportFailure('PDF_FILE_REQUIRED');
      }
      if (file.bytes.length > SelectedPdf.maxBytes) {
        throw const ImportFailure('PDF_TOO_LARGE');
      }
      controller.selectFile(file);
    } catch (failure) {
      if (mounted) controller.showError(failure);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> run({int? retryIndex}) async {
    final secret = password.text;
    password.clear();
    if (widget.mail) {
      await controller.sync(secret, retryIndex: retryIndex);
    } else {
      await controller.upload(secret);
    }
  }

  Future<void> connect() async {
    password.clear();
    final uri = await controller.connect();
    if (!mounted || uri == null) return;
    try {
      final launched = await launchUrl(
        uri,
        webOnlyWindowName: '_self',
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        controller.showError(const ImportFailure('NETWORK'));
      }
    } catch (failure) {
      if (mounted) controller.showError(failure);
    }
  }

  Widget notice(String value, {Color color = Colors.white54}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        value,
        style: TextStyle(fontSize: 11, height: 1.7, color: color),
      ),
    ),
  );
  Widget spinner() => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: lime),
  );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final busy = c.busy || picking || c.loadingConnection;
    final connected = c.connection?['connected'] == true && !c.needsReconnect;
    final supported = c.connection?['supported'] == true;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.mail ? 'Sync ข้อมูล' : 'อัปโหลด PDF',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิดการนำเข้า',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            notice(
              'อ่าน Confirmation หุ้นนอก หุ้นไทย และกองทุนรวม · ตรวจ Preview ก่อนยืนยันบันทึก',
            ),
            const SizedBox(height: 12),
            if (widget.mail) ...[
              if (c.loadingConnection)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: spinner(),
                  ),
                )
              else ...[
                Row(
                  children: [
                    const Icon(Icons.mail_outline, color: lime, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Gmail', style: TextStyle(fontSize: 14)),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => c.loadConnection(),
                      child: const Text('ตรวจสถานะ'),
                    ),
                  ],
                ),
                if (c.connection == null)
                  notice('ยังตรวจสถานะการเชื่อมต่อไม่ได้ กรุณาลองอีกครั้ง')
                else if (!supported)
                  notice(importMessage('MAIL_PROVIDER_UNSUPPORTED'))
                else if (!connected) ...[
                  Panel(
                    child: notice(
                      'Login ด้วย Google ยังไม่ได้ให้สิทธิ์อ่าน Gmail กรุณาเชื่อมต่อและเลือกบัญชีที่มีอีเมลตรงกับ Ruamport',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : connect,
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('เชื่อมต่อ Gmail'),
                  ),
                ] else ...[
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                textValue(
                                      objectMap(
                                        c.connection?['connection'],
                                      )['email'],
                                    ) ??
                                    'เชื่อมต่อ Gmail แล้ว',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: lime,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: busy
                                  ? null
                                  : () => setState(
                                      () => confirmDisconnect =
                                          !confirmDisconnect,
                                    ),
                              child: const Text(
                                'ตัดการเชื่อมต่อ',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (confirmDisconnect) ...[
                          const SizedBox(height: 8),
                          notice(
                            'ยืนยันตัดการเชื่อมต่อ Gmail? เอกสารและรายการลงทุนที่บันทึกไว้จะยังอยู่',
                          ),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    password.clear();
                                    await c.disconnect();
                                    if (mounted) {
                                      setState(() => confirmDisconnect = false);
                                    }
                                  },
                            child: const Text(
                              'ยืนยันตัดการเชื่อมต่อ',
                              style: TextStyle(color: loss),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ช่วงเวลาย้อนหลัง',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 10),
                  IgnorePointer(
                    ignoring: busy,
                    child: ChoiceStrip(
                      labels: const ['ทั้งหมด', '1 เดือน', '2 เดือน'],
                      value: c.months == 'all'
                          ? 'ทั้งหมด'
                          : '${c.months} เดือน',
                      onChanged: (value) {
                        password.clear();
                        c.setMonths(
                          value == 'ทั้งหมด'
                              ? 'all'
                              : value == '1 เดือน'
                              ? 1
                              : 2,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ] else ...[
              InkWell(
                onTap: busy ? null : choosePdf,
                borderRadius: BorderRadius.circular(8),
                child: Panel(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.upload_file_outlined,
                        size: 38,
                        color: lime,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        picking
                            ? 'กำลังเลือกไฟล์…'
                            : c.file?.name ?? 'เลือกไฟล์ PDF',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'ครั้งละ 1 ไฟล์ · ไม่เกิน 10 MB',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!widget.mail || connected && supported) ...[
              const SizedBox(height: 18),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 128,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'รหัสเปิด PDF',
                  counterText: '',
                  hintText: widget.mail
                      ? 'กรอกรหัสก่อนซิงค์ทุกครั้ง'
                      : 'กรอกหากไฟล์มีรหัสผ่าน',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    busy ||
                        (widget.mail
                            ? password.text.trim().isEmpty
                            : c.file == null)
                    ? null
                    : () => run(),
                icon: c.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Icon(
                        widget.mail ? Icons.sync : Icons.description_outlined,
                        size: 18,
                      ),
                label: Text(
                  c.busy
                      ? 'กำลังดำเนินการ…'
                      : widget.mail
                      ? 'ซิงค์ข้อมูล'
                      : 'อ่าน Preview',
                ),
              ),
              if (widget.mail)
                notice(
                  'ค้นหาเฉพาะเมล Dime ตามวันที่รับอีเมล โหลดชุดถัดไปให้อัตโนมัติ รหัสใช้เฉพาะรอบนี้',
                ),
            ],
            if (c.scanning) ...[
              notice(
                'กำลังตรวจหาไฟล์ใหม่… พบแล้ว ${c.progress['foundPdfCount'] ?? 0} ไฟล์',
              ),
              OutlinedButton(
                onPressed: c.stopRequested ? null : c.stop,
                child: Text(
                  c.stopRequested
                      ? 'กำลังหยุดหลังจบชุดนี้…'
                      : 'หยุดโหลดเพิ่มเติม',
                ),
              ),
            ],
            if (c.error != null) notice(c.error!, color: loss),
            if (c.message != null) notice(c.message!, color: lime),
            if (c.preview != null) ...[
              const SizedBox(height: 14),
              if (widget.mail)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : c.closePreview,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('กลับไปรายการ PDF'),
                  ),
                ),
              PdfPreviewView(
                preview: c.preview!,
                record: c.record(c.preview!.record),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy || !c.canSavePreview
                    ? null
                    : () {
                        password.clear();
                        c.save(currentOnly: true);
                      },
                child: Text(
                  c.record(c.preview!.record).imported
                      ? 'บันทึกไว้แล้ว'
                      : 'บันทึกเอกสารนี้เข้าพอร์ต',
                ),
              ),
            ] else if (widget.mail && c.batches.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'พบ PDF ${c.progress['foundPdfCount'] ?? '—'} ไฟล์ · อ่าน Confirmation สำเร็จ ${c.progress['readyPdfCount'] ?? '—'} ไฟล์',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              notice(
                'จำนวน PDF รวมไฟล์ล็อกและประเภทที่ซ่อน ไม่ใช่จำนวนรายการซื้อขายหรือเอกสารไม่ซ้ำ',
              ),
              ChoiceStrip(
                labels: List.generate(
                  c.batches.length,
                  (index) => 'ชุด ${index + 1}',
                ),
                value: 'ชุด ${c.selectedBatchIndex + 1}',
                onChanged: (value) =>
                    c.selectBatch(int.parse(value.split(' ').last) - 1),
              ),
              const SizedBox(height: 14),
              for (final item in c.selectedBatch!.files.where(
                (file) => !file.old,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _fileCard(item, busy),
                ),
              if (c.selectedBatch!.files.where((file) => !file.old).isEmpty)
                notice('ชุดนี้ไม่มี Preview ใหม่'),
              if (c.selectedBatch!.files.any((file) => file.old))
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'เคยอ่าน/บันทึกแล้ว ${c.selectedBatch!.files.where((file) => file.old).length} ไฟล์',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    for (final item in c.selectedBatch!.files.where(
                      (file) => file.old,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _fileCard(item, busy),
                      ),
                  ],
                ),
              if (c.selectedBatch!.files.any((file) => file.locked)) ...[
                notice(
                  'หากมีไฟล์ล็อก ให้กรอกรหัสใหม่ด้านบน แล้วอ่านเฉพาะชุดนี้ซ้ำ',
                ),
                OutlinedButton(
                  onPressed: busy || password.text.trim().isEmpty
                      ? null
                      : () => run(retryIndex: c.selectedBatchIndex),
                  child: Text(
                    'อ่านชุด ${c.selectedBatchIndex + 1} อีกครั้งด้วยรหัสใหม่',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy || c.importableIds.isEmpty
                    ? null
                    : () {
                        password.clear();
                        c.save();
                      },
                child: Text(
                  'บันทึกทั้งหมดที่พร้อม (${c.importableIds.length} เอกสาร)',
                ),
              ),
            ],
            if (c.importResults.isNotEmpty) ...[
              const SizedBox(height: 14),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'บันทึกใหม่ ${c.importResults.where((r) => r['outcome'] == 'IMPORTED').length} · '
                      'บันทึกไว้แล้ว ${c.importResults.where((r) => r['outcome'] == 'ALREADY_IMPORTED').length} · '
                      'ยังไม่สำเร็จ ${c.importResults.where((r) => !['IMPORTED', 'ALREADY_IMPORTED'].contains(r['outcome'])).length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'รายละเอียดผลการบันทึก',
                        style: TextStyle(fontSize: 12),
                      ),
                      children: [
                        for (final result in c.importResults)
                          notice(
                            '${c.documentName(result['documentId'])} · ${_outcome(result)}',
                            color:
                                [
                                  'IMPORTED',
                                  'ALREADY_IMPORTED',
                                ].contains(result['outcome'])
                                ? lime
                                : loss,
                          ),
                      ],
                    ),
                    notice(
                      'รายการที่บันทึกสำเร็จจะอัปเดตข้อมูลพอร์ตหลังยืนยัน',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileCard(MailFile item, bool busy) {
    final record = controller.record(item.record);
    return Panel(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.filename,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            record.imported
                ? 'บันทึกไว้แล้ว'
                : item.old
                ? 'เคยอ่านแล้ว · โหลดรายละเอียดจากฐานข้อมูลได้'
                : item.preview != null
                ? '${item.preview!.orders.length} รายการ · เลขที่เอกสาร ${item.preview!.documentNumber}'
                : importMessage(item.errorCode),
            style: TextStyle(
              fontSize: 10,
              height: 1.6,
              color: item.successful ? Colors.white54 : loss,
            ),
          ),
          if (item.successful)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () {
                        password.clear();
                        controller.view(item);
                      },
                child: Text(
                  item.old ? 'ดูเอกสารที่เก็บไว้' : 'ดู Preview',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _outcome(Map<String, dynamic> result) => switch (result['outcome']) {
    'IMPORTED' =>
      'บันทึกสำเร็จ · เพิ่ม ${result['transactionCount'] ?? '—'} รายการ · ข้ามซ้ำ ${result['duplicateOrderCount'] ?? '—'} รายการ'
          '${result['hasWarnings'] == true || objectList(result['warnings']).isNotEmpty ? ' · มีคำเตือน กรุณาตรวจ Preview' : ''}',
    'ALREADY_IMPORTED' => 'เอกสารนี้บันทึกไว้แล้ว ไม่มีรายการซ้ำ',
    'NOT_FOUND' => 'ไม่พบเอกสาร หรือไม่มีสิทธิ์เข้าถึง',
    'DOCUMENT_NUMBER_REQUIRED' => 'เอกสารไม่มีเลขที่ จึงยังบันทึกไม่ได้',
    'DOCUMENT_DATA_INVALID' => 'ข้อมูลเอกสารไม่ครบ จึงยังบันทึกไม่ได้',
    'ORDER_ID_CONFLICT' =>
      'เลขคำสั่งตรงกับรายการเดิม แต่รายละเอียดต่างกัน ยังไม่บันทึกเอกสารนี้',
    _ => 'ยังยืนยันผลบันทึกไม่ได้ ลองบันทึกอีกครั้งได้โดยไม่สร้างรายการซ้ำ',
  };
}
