# Login บน Flutter Mobile UI (ทดสอบด้วย Edge)

## เริ่มรัน

1. เปิด Backend เดิม `Ruamport_Web/Ruamport_Backend` ที่ `http://localhost:3000` ให้ `/api/v1/health` ใช้งานได้
2. ปิด Angular dev server ก่อนหากพอร์ต 4200 ถูกใช้อยู่
3. รัน Flutter:

```sh
flutter pub get
flutter run -d edge --web-port 4200 --web-hostname localhost
```

ใช้พอร์ตแน่นอนเพื่อให้ session และ PKCE verifier อยู่ origin เดิมเมื่อกลับจาก Social Login Backend ปัจจุบันอนุญาต CORS ของ `http://localhost:4200` อยู่แล้ว ไม่ต้องแก้ Backend สำหรับคำสั่งด้านบน

Supabase → Authentication → URL Configuration → Redirect URLs ต้องอนุญาต:

```text
http://localhost:4200/auth/callback
```

หากเว็บเดิมเข้าสู่ระบบ Social ผ่าน URL นี้อยู่แล้ว สามารถใช้รายการเดิมได้ ไม่ต้องเปลี่ยน Google/Facebook callback ของ provider ซึ่งยังชี้ไป Supabase เหมือนเว็บ

VS Code มี launch configuration **Ruamport Mobile · Edge** ที่กำหนดพอร์ตนี้ไว้แล้ว

## Flow ที่เชื่อมแล้ว

- Username/Password: `POST /api/v1/auth/login-username` → รับ access/refresh token → `Supabase.auth.setSession` → `GET /api/v1/auth/me` พร้อม Bearer token → Dashboard
- Google/Facebook: `signInWithOAuth` แบบ PKCE → `/auth/callback` → SDK รับ session → `/auth/me` → Dashboard
- ชื่อใช้ `profile.username → profile.full_name → user.email` และรูปใช้ `profile.avatar_url` ไม่มีการสร้างหรือแก้ตาราง profiles จาก Flutter
- เก็บ Session ผ่าน Supabase SDK โดยใช้ flutter_secure_storage เป็น storage adapter และให้ SDK refresh token ไม่มีการเก็บรหัสผ่านหรือ log token
- เมื่อรีเฟรชหน้า จะโหลด session เดิมและตรวจ `/auth/me` ก่อนแสดง Dashboard
- หาก Backend โหลดโปรไฟล์ไม่สำเร็จ จะมีปุ่มลองใหม่/กลับไปเข้าสู่ระบบ ไม่ใส่โปรไฟล์สมมติแทน
- หาก `/auth/me` ตอบ 401 จะลอง refresh หนึ่งครั้ง หากยังไม่ได้จะออกจาก session และให้เข้าสู่ระบบใหม่
- Logout ใช้ scope local จึงไม่สั่งออกจากระบบทุกอุปกรณ์
- Logout จาก Dashboard กลับหน้า Login โดยตรง และล้างหน้ารายละเอียดที่เปิดค้างไว้
- รูปมุมขวาบน ในเมนูเพิ่มเติม และในโปรไฟล์ ใช้ `profile.avatar_url` มีตัวแสดงระหว่างโหลดและไอคอนสำรองหากโหลดรูปไม่ได้
- โปรไฟล์แก้ Username และตั้ง/เปลี่ยนรหัสผ่านได้ผ่าน `PATCH /auth/credentials` ส่งเฉพาะค่าที่เปลี่ยน แสดงข้อความ Username ซ้ำ และรับ Session ใหม่เมื่อเปลี่ยนรหัสผ่าน
- หาก Backend เปลี่ยนรหัสผ่านแล้วแต่สร้าง Session ใหม่ไม่สำเร็จ จะกลับ Login พร้อมข้อความให้ลองใช้รหัสผ่านใหม่ ไม่ส่งคำขอเปลี่ยนรหัสผ่านซ้ำอัตโนมัติ

Username/Password ใช้ได้กับบัญชีที่ตั้งรหัสผ่านในระบบเดิมแล้ว บัญชีใหม่ให้เริ่มด้วย Google หรือ Facebook ไม่เพิ่ม Apple หรือ Outlook

## ขอบเขต

เชื่อม Login และโปรไฟล์แล้ว Full name, Email และรูปเป็นแบบอ่านอย่างเดียว แก้ได้เฉพาะ Username และรหัสผ่านตาม Backend ระบบ PDF/Gmail เชื่อมแล้ว ดู [คู่มือนำเข้า](MOBILE_IMPORT.md) ข้อมูล Dashboard ใช้ Backend จริงตาม [คู่มือข้อมูลพอร์ต](MOBILE_PORTFOLIO_DATA.md) ส่วน Forgot Password ยังไม่เชื่อม

การรันจาก `main.dart` ใช้ Auth จริง ปุ่มดู Dashboard ตัวอย่างใน widget tests ใช้เฉพาะกรณีสร้าง `RuamportApp` โดยไม่ได้ส่ง AuthController

## ปรับค่าเชื่อมต่อ

ตั้งค่าได้ด้วย `--dart-define=API_BASE_URL=...`, `SUPABASE_URL` และ `SUPABASE_PUBLISHABLE_KEY` ค่าเริ่มต้นอิงเว็บเดิม ห้ามใส่ service role key ใน Flutter

หากเปลี่ยนพอร์ต Edge ต้องเพิ่ม CORS origin ของ Backend และ Redirect URL ของ Supabase ให้ตรงด้วย Browser อาจรายงาน CORS เป็น network error ซึ่งแอปจะแสดงข้อความเชื่อมต่อไม่ได้

Android Emulator ใช้ค่า API เริ่มต้น `http://10.0.2.2:3000/api/v1`; มือถือจริงต้องใช้ที่อยู่ Backend ที่เครื่องเข้าถึงได้

## Android OAuth callback

AndroidManifest ลงทะเบียน `io.ruamport.mobile://auth/callback` ให้ MainActivity (`singleTop`) และปิด Flutter default deep linking เพื่อให้ Supabase/app_links รับ callback และแลก PKCE code เป็น Session ตามที่ `main.dart` รองรับอยู่แล้ว

ผู้ใช้ต้องเพิ่ม `io.ruamport.mobile://auth/callback` ใน Supabase Dashboard → Authentication → URL Configuration → Redirect URLs แล้ว Save เอง โดยคง URL ของเว็บและ Site URL เดิมไว้ การแก้รอบนี้ไม่ได้เปลี่ยน Backend, การตั้งค่า Supabase หรือ flow ของเว็บ

หลังเปลี่ยน Manifest ให้ Stop แล้วรัน `flutter run -d emulator-5554` ใหม่ (หรือ device id ของเครื่องที่ใช้) เพื่อ Build/ติดตั้ง APK ใหม่ Hot Reload/Hot Restart ไม่อัปเดต Manifest

ตรวจการรับลิงก์ของ APK ที่ติดตั้งใหม่ได้ด้วย `adb shell cmd package resolve-activity --brief -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -p com.example.project_portfoliomanagement_mobile -d "io.ruamport.mobile://auth/callback"` ควรพบ MainActivity คำสั่งนี้ไม่ส่ง OAuth code และไม่ Login จริง

callback ของ Web ยังคงเป็น `${Uri.base.origin}/auth/callback` เหมือนเดิม ไม่มีการเปลี่ยนโค้ด Dart สำหรับเปิด OAuth หรือรับ Session ในรอบนี้

อ้างอิง SDK: [Supabase Flutter OAuth](https://supabase.com/docs/reference/dart/auth-signinwithoauth), [setSession](https://supabase.com/docs/reference/dart/auth-setsession)
