# Ruamport Mobile — Flutter

ต้นแบบหน้าตาแอปมือถือ อ้างอิง Ruamport Web ใช้ธีมดำ สีเขียว `#78FF61` ฟอนต์ Kanit และ assets ในโปรเจกต์

## เริ่มใช้งาน

```sh
flutter pub get
flutter run -d edge --web-port 4200 --web-hostname localhost
```

เข้า Homepage → Get started → Login ด้วย Username/Password หรือ Google/Facebook → โหลดโปรไฟล์จริงจาก Backend → Dashboard

เริ่ม Backend เดิมที่พอร์ต 3000 ก่อน และปิด Angular dev server หากใช้พอร์ต 4200 อยู่ พอร์ตนี้ใช้ CORS origin และ OAuth callback เดียวกับเว็บเดิม ดูรายละเอียดที่ [คู่มือ Login](docs/MOBILE_LOGIN.md)

## หน้าที่ทำไว้

- Overview: มูลค่าพอร์ต กราฟย้อนหลัง สัดส่วนสินทรัพย์ กำไรขาดทุน และเทียบตลาด
- Portfolio: หุ้นนอก หุ้นไทย กองทุน ค้นหา เรียงลำดับ และเลือก USD/THB สำหรับหุ้นนอก
- Stock: รายละเอียดสินทรัพย์และประวัติซื้อขายตามเอกสาร
- Analytics: กราฟเทียบตลาด อัตราชนะตลาด ที่มาของกำไร และสินทรัพย์ที่ส่งผลต่อพอร์ต
- Simulator: จำลองซื้อ/ขาย หาจำนวนซื้อเพื่อให้ถึงต้นทุนเฉลี่ยเป้าหมาย และจำลองราคาหุ้นเป้าหมาย
- เพิ่มเติม: โปรไฟล์ News, Contact us และตัวอย่างนำเข้า PDF/Sync อีเมล

เมนูหลักอยู่ด้านล่าง การสลับหน้าเก็บสถานะไว้ระหว่างใช้งาน ส่วนฟอร์มเปิดเป็น Bottom Sheet เพื่อให้เหมาะกับมือถือ

## ขอบเขตข้อมูลตัวอย่าง

หลัง Login จริง หน้า Overview, Portfolio, Stock, Analytics และ Simulator ใช้ข้อมูลจาก Backend เดียวกับเว็บ ไม่มีการแทนข้อมูลที่โหลดล้มเหลวด้วยพอร์ตตัวอย่าง ดูรายละเอียดที่ [คู่มือข้อมูลพอร์ต](docs/MOBILE_PORTFOLIO_DATA.md)

ข้อมูลใน `lib/core/demo/demo_portfolio.dart` คงไว้เฉพาะโหมด UI ตัวอย่าง/การทดสอบที่ไม่ได้ส่ง AuthController เท่านั้น News และ Contact us ยังเป็น UI ที่รอเชื่อมต่อ

โปรไฟล์จริงแสดง Full name, Email และรูปจาก `/auth/me` พร้อมแก้ Username และตั้ง/เปลี่ยนรหัสผ่านผ่าน Backend ได้ เมื่อเปลี่ยนรหัสผ่านจะรับ Session ใหม่จาก response

อัปโหลด PDF และ Gmail Sync อ่าน Preview จริง รองรับหุ้นนอก หุ้นไทย และกองทุนรวม ต้องกดบันทึกเพื่อยืนยันนำเข้ารายการลงทุน ไม่มีการแก้ไขรายการที่อ่านได้ใน Flutter ดู [คู่มือนำเข้า](docs/MOBILE_IMPORT.md) ส่วน Contact us ยังไม่ส่ง Ticket

Simulator ใช้จำนวนถือครองและต้นทุนจริง การจำลองขายเรียก `/trades/simulate-sale` ให้ Backend คำนวณตามวิธีต้นทุนของแต่ละสินทรัพย์ การจำลองซื้อ ต้นทุนเป้าหมาย และราคาเป้าหมายเป็นการคำนวณในเครื่องจากข้อมูลจริง โดยไม่บันทึกรายการลงทุน

## โครงสร้าง

- `lib/core/theme/`: สี ฟอนต์ และรูปแบบพื้นฐาน
- `lib/core/demo/`: ข้อมูลพอร์ตตัวอย่างและตัวช่วยจัดรูปแบบตัวเลข
- `lib/features/`: แยกหน้าและฟอร์มตามหน้าที่
- `lib/shared/widgets/`: กรอบ การ์ด กราฟ และส่วนประกอบที่ใช้ซ้ำ
- `assets/`: โลโก้ รูปภาพ และฟอนต์เดิม

## ตรวจสอบ

```sh
flutter analyze
flutter test
```

ทดสอบการนำทาง หน้าจอกว้าง 320/390/600 logical pixels การเปิดรายละเอียดหุ้น ฟอร์ม Contact us, News, Simulator และการบังคับกรอกรหัสก่อนดูตัวอย่าง Sync

สร้างภาพตัวอย่างจาก Flutter widget tests:

```sh
flutter test --dart-define=CAPTURE_MOBILE_UI=true
```

ภาพอยู่ใน `build/ui-previews/` เป็นภาพเรนเดอร์จาก Flutter test ไม่ใช่ภาพจากอุปกรณ์จริง
