// เลือกตัวแสดงภาพตามแพลตฟอร์ม ไม่ให้ Android/iOS ต้อง import browser API
export 'avatar_image_native.dart'
    if (dart.library.js_interop) 'avatar_image_web.dart';
