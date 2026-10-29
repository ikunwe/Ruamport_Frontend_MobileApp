# Mobile: รอ Backend และ retry เฉพาะ GET

เพิ่มตาม FRONTEND_BACKEND_READINESS_GUIDE.md ใช้นโยบายเดียวกับ Angular Web โดยไม่เปลี่ยน Backend หรือ UI หน้าหลัก

## จุดเชื่อมกลาง

- AuthController ถือ BackendClient หนึ่งตัวต่อแอป ImportApi.forAuth ใช้ตัวเดียวกันทุกหน้า รวม Portfolio และ PDF/Gmail modal จึงแชร์ health flight และ READY ต่อ origin
- Health URL ใช้ BACKEND_HEALTH_URL เมื่อกำหนด หรือ derive จาก API_BASE_URL เดิม (รวม Android Emulator) ไม่สลับ host เอง ตรวจ origin ต้องตรงกันและห้าม localhost ใน release
- ยืนยันเฉพาะ HTTP 200 + status=ok + service=portfolio-api ไม่ได้ยืนยัน Session/provider พร้อม
- Health ไม่ขอ Session/ไม่แนบ token บน Edge ใช้ fetch cache=no-store, credentials=omit, redirect=error โดยไม่เพิ่ม header ที่ขัด CORS เดิม บน native ใช้ client แยกและ Cache-Control no-store
- Health timeout 1,500ms ต่อครั้ง, สูงสุด 4 ครั้ง หน่วง 500/1,000/2,000ms และ deadline รวม 10 วินาที READY อยู่ RAM 5 วินาที ไม่มี health polling ตอนว่าง
- แต่ละ waiter ยกเลิกแยกกันได้ ยกเลิกคนสุดท้าย abort request/timer ของ health

## คำขอธุรกิจ

- เริ่ม deadline ก่อนรอ health และอ่าน token ล่าสุดหลัง health ผ่าน ทุก retry อ่านใหม่ Analytics/กราฟมี 180 วินาทีรวม; ไม่เริ่ม timeout ใหม่แต่ละ attempt
- Retry เฉพาะ GET ที่อยู่ใน allowlist ของ origin/path Backend เมื่อเป็น network ClientException สูงสุด 3 business attempts หน่วง 500/1,500ms invalidate READY และเช็ก health ใหม่
- HTTP errors จริง, TimeoutException, RequestAbortedException, HTTP200 PARTIAL/INCOMPLETE/retryAt ไม่เข้า network retry
- POST/PATCH/PUT/DELETE รวม Login/import/upload/simulator ส่งครั้งเดียว ไม่ resend แม้อาจบันทึกไปแล้ว
- Browser ถ้าระบุ offline ให้หยุดทันที Native ที่ไม่มี offline hint ใช้ retry แบบจำกัด ไม่วินิจฉัยจาก network error ว่า Backend ปิดหรือ Session หมดอายุ
- status network/health ไม่ logout; คงการแปล HTTP401 ของ Auth และ UNAUTHORIZED ของ ImportApi ตามเดิม
- ใช้ AbortableRequest/AbortableMultipartRequest และ cancellation scope เพื่อ abort network จริงเมื่อ timeout/logout/account switch/dispose

## กราฟและ cache

- เปลี่ยนช่วงกราฟ/ดัชนี หรือ dispose จะยกเลิก request เก่า Overview/Analytics หยุดงานที่ค้างเมื่อสลับออกจากแท็บ
- Request cache ยังแชร์ business flight เดิม แต่แต่ละ consumer มี cancellation ของตัวเอง ยกเลิกทุก consumer จึง abort งานจริง ไม่มี cache จาก error/cancel ไม่ขยับ expiry ของข้อมูลเดิม
- Import modal dispose ยกเลิกเฉพาะงานของ modal ไม่ปิด client ที่หน้าอื่นใช้ร่วมกัน Logout/account switch ยกเลิก scope ของบัญชีเก่า

## UI

คง layout/style เดิม เพิ่มข้อความชั่วคราว “กำลังเชื่อมต่อระบบ…” เฉพาะตอน health ทำงาน เมื่อไม่พร้อมแสดง “เชื่อมต่อระบบไม่ได้ กรุณาลองใหม่” ผ่านช่อง error เดิม ปุ่มลองใหม่และปุ่ม submit เดิมเป็นการเริ่มรอบใหม่โดยผู้ใช้ Loading คืนใน finally

## ทดสอบ

backend_readiness_test.dart ใช้ mock HTTP และ Flutter fake timers ตรวจ single-flight, TTL, deadlines, health contract, retries, mutation ไม่ซ้ำ, cancellation, offline และ origin policy โดยไม่ใช้บัญชีจริง

Contract tests เดิม opt-out health ด้วย checkReadiness:false เพื่อไม่เปลี่ยนวัตถุประสงค์ของ fixture; ค่าเริ่มต้นของ runtime เป็น true เสมอ

หลังอัปเดตนี้ให้ Hot Restart ครั้งหนึ่ง เพราะเปลี่ยน fields/constructor ของ AuthController และ ImportApi
