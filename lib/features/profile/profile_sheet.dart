import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/show_notice.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.onLogout, this.onNameChanged});
  final VoidCallback onLogout;
  final ValueChanged<String>? onNameChanged;
  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: 'ผู้ใช้งานตัวอย่าง');
  final username = TextEditingController(text: 'ruamport_demo');
  final password = TextEditingController(),
      confirmation = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ข้อมูลโปรไฟล์',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'ปิดโปรไฟล์',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFF20351C),
                child: Icon(Icons.person_outline, color: lime, size: 34),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'โปรไฟล์ตัวอย่าง',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: name,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'กรอกชื่อที่ต้องการแสดง'
                  : null,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: username,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'กรอก Username'
                  : null,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: 'demo@ruamport.app',
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.check_circle_outline, color: lime, size: 15),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'ตั้งค่า Username แล้ว · สถานะตัวอย่าง',
                    style: TextStyle(color: lime, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'ตั้งค่ารหัสผ่าน',
                style: TextStyle(fontSize: 13),
              ),
              subtitle: const Text(
                'ฟอร์มตัวอย่าง ยังไม่เปลี่ยนรหัสจริง',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              children: [
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่'),
                  validator: (value) =>
                      value != null && value.isNotEmpty && value.length < 8
                      ? 'กรอกอย่างน้อย 8 ตัวอักษร'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'ยืนยันรหัสผ่าน',
                  ),
                  validator: (value) => password.text != (value ?? '')
                      ? 'รหัสผ่านไม่ตรงกัน'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                widget.onNameChanged?.call(name.text.trim());
                notice(
                  context,
                  'อัปเดตชื่อในตัวอย่าง UI เท่านั้น ยังไม่บันทึกบัญชีจริง',
                );
              },
              child: const Text('บันทึกตัวอย่าง'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              child: const Text(
                'ออกจากโหมดตัวอย่าง',
                style: TextStyle(color: loss),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
