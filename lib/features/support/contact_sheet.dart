import 'package:flutter/material.dart';

class ContactSheet extends StatelessWidget {
  const ContactSheet({super.key});
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
              const Expanded(
                child: Text(
                  'Contact us',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'ปิด Contact us',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const Text(
            'แจ้งปัญหา หรือเสนอแนะถึงทีมผู้ดูแล',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 22),
          const TextField(
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'หัวข้อเรื่อง',
              hintText: 'เช่น ปัญหาการซิงค์พอร์ต',
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            maxLines: 5,
            maxLength: 3000,
            decoration: InputDecoration(
              labelText: 'รายละเอียด',
              alignLabelWithHint: true,
              hintText: 'เล่าปัญหาหรือสิ่งที่อยากให้ปรับปรุง',
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD675).withValues(alpha: .07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ระบบ Ticket จะเปิดใช้งานเร็ว ๆ นี้\nข้อความในฟอร์มยังไม่ถูกส่งถึงทีมผู้ดูแล',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFFFD675),
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const FilledButton(onPressed: null, child: Text('ส่งข้อความ')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    ),
  );
}
