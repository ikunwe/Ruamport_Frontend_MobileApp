# PDF Preview และ Gmail Sync บน Flutter

ทดสอบบน Edge โดยใช้ Backend เดิม ไม่แก้ Angular หรือโค้ด Backend

```sh
flutter run -d edge --web-port 4200 --web-hostname localhost
```

หลัง Login ใช้ปุ่มเพิ่มข้อมูลด้านบน หรือเมนูเพิ่มเติม → อัปโหลด PDF / Sync ข้อมูล

## PDF

- เลือก PDF ครั้งละ 1 ไฟล์ ขนาดไม่เกิน 10 MB ตรวจขนาดก่อนอ่าน bytes เข้าหน่วยความจำ
- กรอกรหัสหากไฟล์ล็อก แล้วกดอ่าน Preview ส่ง multipart `file` กับ `pdfPassword` ไป `POST /trades/upload-preview` โดยไม่กำหนด boundary เอง
- แสดงหุ้นนอก หุ้นไทย และกองทุนรวมตาม `document.type` พร้อมรายการ วันที่ซื้อขาย จำนวน ราคา/NAV ยอดเงิน และเลขเอกสาร
- หุ้นนอกใช้ยอด `display` จากเอกสาร ไม่ใช้ `summary` หรือ `calculation` แทนเมื่อยอดเป็น null หุ้นไทยและกองทุนใช้ `summary`
- ค่าไม่มีแสดง `—` ไม่แปลงเป็นศูนย์ ไม่คำนวณยอด PDF ใหม่หรือใช้เรทปัจจุบัน
- แสดงเฉพาะ `validation.warnings` พร้อม calculatedValue/pdfValue หากมี ไม่แสดง diagnostics และไม่ปิดปุ่มเพียงเพราะ isValid=false
- Monthly ยังปิดใช้งาน แจ้งตาม Backend แทนการแจ้งว่าไฟล์เสีย

## Gmail

- โหลด `GET /mail/connection` ก่อน ถ้า supported=false ให้ใช้อัปโหลด PDF ไม่มีตัวเลือก Outlook
- การ Login ด้วย Google ไม่ได้ให้สิทธิ์อ่านเมลโดยอัตโนมัติ ต้องกดเชื่อม Gmail แยก
- `POST /mail/gmail/connect` → ตรวจ authorizationUrl ว่าเป็น HTTPS ของ accounts.google.com → เปิดหน้าอนุญาต ไม่ส่ง Bearer token ใน URL
- Backend callback ยังเป็น `/api/v1/mail/gmail/callback` แล้วกลับ `http://localhost:4200/mail/return` ตามค่า Backend ที่มีอยู่
- Flutter รับ route นี้และเปิด Sync ใหม่ จากนั้นตรวจ `/mail/connection` จริง ไม่เชื่อ query ว่าเชื่อมสำเร็จ
- Supabase รับ code เฉพาะ `/auth/callback` เพื่อไม่สับสนกับ error code ของ Gmail ที่ `/mail/return`
- เลือกทั้งหมด/1/2 เดือน กรอกรหัส PDF ก่อนกดซิงค์ ส่ง `months`, `pdfPassword`, `cursor` ตาม response เท่านั้น
- โหลดทีละ request จน hasMore=false รวมถึงชุดที่ results ว่าง ไม่แก้หรือสร้าง cursor เอง มีปุ่มหยุดหลังคำขอปัจจุบันจบ
- เลือกดูแต่ละชุดจากข้อมูลในหน่วยความจำ ไม่ส่ง request ซ้ำเมื่อเปลี่ยนแท็บชุด
- ใช้ progress.foundPdfCount ซึ่งเป็นยอดสะสมโดยตรง ไม่บวกทุกชุดซ้ำ
- อ่านชุดล็อกซ้ำด้วย retryCursor และรหัสใหม่ แทนที่ผลชุดเดิมโดยเก็บไฟล์ที่ปลดล็อกสำเร็จไว้ ไม่ทับ progress ของชุดใหม่กว่าด้วย counter จากชุดเก่า
- READY แสดง Preview ใหม่ ส่วน ALREADY_READ/ALREADY_IMPORTED แสดงเป็นประวัติพับเก็บ กดดูจึงเรียก `GET /trades/documents/:id` ไม่ parse PDF ใหม่
- เริ่มซิงค์รอบใหม่ล้าง Preview เดิม ไม่แสดง Preview เก่าเป็นผลใหม่ Monthly ที่ Backend ระบุจะซ่อน
- MAIL_RECONNECT_REQUIRED ให้เชื่อมเมลใหม่ ไม่สั่ง Logout บัญชี Ruamport
- ตัดการเชื่อมต่อผ่าน DELETE หลังผู้ใช้ยืนยัน ไม่ลบเอกสารหรือรายการลงทุน

## ยืนยันบันทึก

Preview อาจถูกเก็บเป็นเอกสาร/ประวัติอ่านที่ Backend แล้ว แต่ยังไม่เป็นรายการลงทุนจนผู้ใช้กดบันทึก

- กดบันทึกเอกสารนี้ หรือบันทึกทั้งหมดที่พร้อม
- ใช้ `record.status=PREVIEW`, `record.canImport=true` และ `validation.blocksImport !== true` เป็นเงื่อนไข
- ส่งเฉพาะ `{documentIds: [...]}` ไป `POST /trades/import` ไม่ส่ง orders/ยอดเงิน/userId และไม่ให้แก้ข้อมูล PDF
- แบ่ง ID ไม่ซ้ำเป็นชุดละไม่เกิน 50 ตรวจ outcome ทุกเอกสาร ไม่ถือว่า HTTP 200 สำเร็จทั้งหมด
- IMPORTED/ALREADY_IMPORTED เปลี่ยนสถานะและปิดปุ่มซ้ำ ผลไม่สำเร็จ/ไม่ยืนยันยังลองใหม่ได้ Backend กันซ้ำให้
- ถ้าคำขอขาดช่วง เอกสารก่อนหน้าอาจบันทึกสำเร็จแล้ว ไม่ auto-retry การบันทึก

หลังบันทึกสำเร็จจะโหลด holdings ใหม่ให้ Overview/Portfolio/Simulator และล้าง cache กราฟเมื่อรายการลงทุนเปลี่ยน หากมี request โหลดพอร์ตค้างอยู่ จะโหลดอีกครั้งหลังคำขอนั้นจบเพื่อไม่พลาดผลนำเข้า ดู [คู่มือข้อมูลพอร์ต](MOBILE_PORTFOLIO_DATA.md)

## Session และข้อมูลส่วนตัว

ทุก API แนบ Supabase Bearer token ไม่ใส่ token ใน URL ไม่ log/persist PDF bytes, รหัส PDF หรือรายละเอียดซื้อขาย ปิดหน้าหรือจบคำขอแล้วล้างรหัส และปล่อยข้อมูล Preview เมื่อปิด Sheet

การยืนยัน Gmail ต้องทำด้วยบัญชีของผู้ใช้เอง การทดสอบอัตโนมัติใช้ mock HTTP เพื่อไม่อ่านเมลหรือบันทึกเอกสารจริงในบัญชีผู้ใช้
