import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';

class ImportSheet extends StatefulWidget {
  const ImportSheet({super.key, required this.mail, required this.onPreview});
  final bool mail;
  final VoidCallback onPreview;
  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  String period = '1 เดือน', password = '', batch = 'ชุด 1';
  bool selectedFile = false, preview = false, completed = false;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
          const Text(
            'ตัวอย่างขั้นตอนนำเข้า · ไม่อ่านอีเมลหรือไฟล์จริง',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 22),
          if (!preview) ...[
            if (widget.mail) ...[
              const Row(
                children: [
                  Icon(Icons.mail_outline, size: 20, color: lime),
                  SizedBox(width: 8),
                  Text('Gmail', style: TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'ช่วงเวลาที่ต้องการซิงค์',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 10),
              ChoiceStrip(
                labels: const ['1 เดือน', '2 เดือน', 'ทั้งหมด'],
                value: period,
                onChanged: (v) => setState(() => period = v),
              ),
            ] else
              InkWell(
                onTap: () => setState(() => selectedFile = true),
                borderRadius: BorderRadius.circular(8),
                child: Panel(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.upload_file_outlined,
                        size: 40,
                        color: lime,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedFile
                            ? 'confirmation_demo.pdf'
                            : 'เลือกไฟล์ตัวอย่าง PDF',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Confirmation หุ้นนอก หุ้นไทย และกองทุน',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              onChanged: (value) => setState(() => password = value),
              decoration: const InputDecoration(
                labelText: 'รหัสผ่าน PDF',
                hintText: 'กรอกรหัสตัวอย่างเพื่อทดลอง UI',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  password.trim().isEmpty || !widget.mail && !selectedFile
                  ? null
                  : () => setState(() => preview = true),
              icon: Icon(
                widget.mail ? Icons.sync : Icons.description_outlined,
                size: 18,
              ),
              label: Text(widget.mail ? 'ดูตัวอย่างผลซิงค์' : 'ดูตัวอย่าง PDF'),
            ),
          ] else ...[
            ChoiceStrip(
              labels: const ['ชุด 1', 'ชุด 2'],
              value: batch,
              onChanged: (value) => setState(() => batch = value),
            ),
            const SizedBox(height: 16),
            const Text(
              'ตัวอย่างเอกสารที่พบ 3 ไฟล์',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Icon(
                        i == 2
                            ? Icons.lock_outline
                            : Icons.description_outlined,
                        color: i == 2 ? Colors.white38 : lime,
                        size: 25,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                'หุ้นนอก · NVDA',
                                'กองทุน · KKP US500',
                                'Monthly statement',
                              ][i],
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              i == 2
                                  ? 'ล็อกไฟล์ · ตัวอย่างสถานะ'
                                  : 'เลขที่เอกสาร DEMO-00${i + 1} · 2 รายการ',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: completed
                  ? null
                  : () {
                      setState(() => completed = true);
                      widget.onPreview();
                    },
              child: Text(
                completed ? 'ดูตัวอย่างการนำเข้าแล้ว' : 'ทดลองยืนยันตัวอย่าง',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'การกดยืนยันเป็นเพียงการแสดง UI ไม่มีการส่งหรือบันทึกข้อมูล',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ],
      ),
    ),
  );
}
