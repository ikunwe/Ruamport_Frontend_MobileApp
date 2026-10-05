import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/show_notice.dart';

class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: lime,
              child: Icon(Icons.person_outline, color: Colors.black, size: 36),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ข้อมูลโปรไฟล์',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: 'ผู้ใช้งานตัวอย่าง',
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: 'ruamport_demo',
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: 'demo@example.com',
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () => notice(context, 'โปรไฟล์นี้เป็นข้อมูลตัวอย่าง'),
            child: const Text('บันทึกการแก้ไข'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onLogout();
            },
            child: const Text('กลับหน้า Login'),
          ),
        ],
      ),
    ),
  );
}
