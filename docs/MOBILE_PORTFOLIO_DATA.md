# การเชื่อมข้อมูลพอร์ตจริงใน Flutter

ใช้ Backend ของ Angular Web เดิม ไม่มีการแก้โค้ดเว็บ/Backend ทุก request แนบ Supabase Bearer token หลัง Login

## ข้อมูลร่วมกัน

Dashboard สร้าง `PortfolioStore` ต่อบัญชี ดึง `/trades/holdings?includeClosed=true&includeFx=true&includeMarket=true&includeLogos=true` ครั้งเดียวแล้วใช้ร่วมกับทุกหน้า ปิดรายการขายหมดจากรายการถือครอง แต่เก็บไว้รวมซื้อขายสะสม ค่าธรรมเนียม และกำไรที่ขายแล้ว

ผลโหลดไม่สำเร็จแสดงข้อความและปุ่มลองใหม่ ค่าที่ Backend ให้ null หรือ status ไม่ครบแสดง `—` ไม่เดาเป็นศูนย์ และไม่ใช้ข้อมูลตัวอย่างแทนหลัง Login บัญชีจริง

## Portfolio และ Stock

- แยกหมวดหุ้นนอก หุ้นไทย กองทุน ค้นหาและเรียงลำดับในเครื่อง
- ราคาหุ้น/NAV, โลโก้, กำไรสินทรัพย์, เปอร์เซ็นต์เปลี่ยนแปลงรายวัน อ่านจาก marketValuation/latestChange ของ Backend ไม่มีการเรียก Finnhub/SEC/Yahoo จาก Flutter โดยตรง
- ต้นทุนรวมของหมวดใน Portfolio ใช้ costBasis สกุลที่เลือกตามเอกสาร รวมรายการปิดแล้วที่มีต้นทุนคงเหลือศูนย์
- ซื้อสะสมของหุ้นใช้ totalBuyGross; กองทุนใช้ totalBuy ขายสะสมใช้ totalSell และค่าธรรมเนียมใช้ totalFeeIncludeVat พร้อมตรวจ complete flags
- ซื้อ/ขายสะสมและค่าธรรมเนียมใน THB เป็นยอดเดิมตามเอกสาร ไม่คูณเรทปัจจุบัน
- หน้า Stock เมื่อเลือก THB ของหุ้นนอก ใช้ displayThb.costBasis สำหรับ snapshot ต้นทุน/เฉลี่ย เช่นเดียวกับหน้า Stock ของเว็บ ยอดประวัติยังคงตามเอกสาร
- Portfolio และ Stock ใช้ตัวเลือก USD/THB ร่วมกัน หมวดไทย/กองทุนใช้ THB
- ประวัติซื้อขายโหลดทุกหน้าของ `/trades/documents` และ `/trades/transactions` แล้วจับคู่ด้วยประเภท บัญชี symbol ตลาด และสกุลเงิน ไม่จับด้วย symbol เพียงอย่างเดียว และตัดรายการ is_duplicate
- โลโก้ไม่เปลี่ยนตัวตน symbol/ตลาดตาม PDF หากไม่มีหรือโหลดไม่ได้ใช้อักษรย่อแทน

## Overview

- มูลค่าทั้งพอร์ตเป็นผลรวม category valuation ใน THB ที่ Backend ส่ง ถ้าบางหมวดประเมินไม่ครบจะไม่อ้างว่าเป็นยอดรวมครบแล้ว
- ต้นทุนรวมตามเอกสารใช้ remainingCostTotals แถว THB ที่ isComplete=true
- กำไรจากสินทรัพย์เป็น unrealizedPnl ของแต่ละหมวดใน THB
- กำไรค่าเงินคือ USD remaining principal ที่เรทปัจจุบัน ลบต้นทุน THB เดิม เฉพาะหุ้นนอกที่ยังถือ ไม่แปลงยอดขายหรือค่าธรรมเนียมใหม่
- Unrealized = กำไรจากสินทรัพย์ + กำไรค่าเงิน
- Realized ใช้ realizedPnlTotals แถว THB ของ Backend รวมขายบางส่วนและรายการปิดแล้ว ไม่แปลง USD มาทดแทนเมื่อไม่มี THB
- กำไรรวม = Unrealized + Realized เปอร์เซ็นต์เทียบต้นทุนคงเหลือ + soldCost ตามที่ตกลงกับเว็บ
- กราฟใช้ `/trades/portfolio-history?range=...` ไม่มีการสร้างจุดสมมติหรือเชื่อมเส้นข้ามจุดที่ไม่มีค่า
- การเปลี่ยนแปลงวันก่อนหน้าใช้ latestChange.portfolio ที่ isComplete=true
- สัดส่วนรวมใช้หุ้นนอก/ไทย/กองทุน หรือเลือกดูรายหมวด ไม่แสดงสัดส่วนเทียมเมื่อข้อมูลไม่ครบ
- Your port vs Market ใช้การเปลี่ยนแปลงจากวันก่อนหน้าเหมือนเว็บ โดย Your port อ่าน latestChange.portfolio และตลาดอ่าน `/trades/market-indices` ครบ S&P 500, NASDAQ, Dow Jones, SET, SET50 หากยังไม่มีข้อมูลแสดง — ไม่ซ่อนตลาดหรือแทนด้วยศูนย์ โหลดใหม่ทุก 15 นาทีและรอ retryAt เมื่อ Backend ระบุ
- โลโก้หุ้นไทยและ บลจ. กองทุนใช้ logoUrl หรือ logo.url แม้สถานะ UNVERIFIED / verified=false เพราะ Backend ไม่ได้ดาวน์โหลดรูปมายืนยัน บน Edge ใช้ HTML img พร้อม no-referrer หากโหลดไม่สำเร็จแสดงอักษรย่อแทน ไม่ยิงซ้ำ URL เดิม

## Analytics

โหลดเมื่อเปิดแท็บ Analytics ใช้ performance และ win-rate จาก `/trades/analytics/` ตาม category/range/benchmarkId/unit รองรับ calculationVersion=2 ที่รวมวันลงทุนแรก เลือก S&P 500, NASDAQ, SET, SET50 และรายสัปดาห์/เดือน/ปี

กราฟใช้ portfolioReturnPercent/benchmarkReturnPercent จริง ช่องที่ไม่มีค่าทิ้งเป็นช่องว่าง อัตราชนะและ WIN/LOSS/TIE/PENDING/INCOMPLETE ใช้ผล Backend ไม่สร้าง winrate เอง ที่มาของกำไรและ contribution ใช้ holdings จริง โดยค่าเงินแสดงเฉพาะทั้งพอร์ตและหุ้นนอก

## Simulator

ใช้สินทรัพย์ HELD จริงพร้อมจำนวน ต้นทุน และราคา native currency

- ซื้อ: คำนวณจำนวน/ต้นทุน/เฉลี่ยหลังซื้อในเครื่อง ไม่รวมค่าธรรมเนียม
- ขาย: POST `/trades/simulate-sale` ใช้ account/symbol/exchange/currency จาก holding และวันที่ปัจจุบันในไทย ไม่ส่งค่าต้นทุนให้ server และไม่ใช้ lot สมมติ
- ตรวจ persisted=false, snapshot revision, identity และวิธีต้นทุนใน response ก่อนใช้ผล ถ้าพอร์ตเปลี่ยนให้โหลดใหม่
- ต้นทุนเป้าหมาย/ราคาเป้าหมายคำนวณในเครื่องจากต้นทุนจริง ไม่สร้างคำสั่งซื้อขายและไม่แก้ holdings

## Cache และ lifecycle

เก็บ response ในหน่วยความจำต่อบัญชี/พารามิเตอร์ แชร์ in-flight request เดียวกันและใช้ expiry ของ response เมื่อมี (fallback 5 นาที) การสลับหน้าไม่ขอข้อมูลเดิมซ้ำทันที

ราคา/โลโก้/FX refresh จาก Backend ตาม expiry/retryAt โดยเว้นอย่างน้อย 1 นาที หยุด timer เมื่อแอปไม่ active และปิดต่อเมื่อ Logout ราคาเปลี่ยนไม่ล้างกราฟที่เก็บไว้ แต่รายการลงทุนเปลี่ยนจะล้าง cache และโหลดกราฟใหม่

หลังยืนยันนำเข้าจะขอ holdings ใหม่ รวมถึงกรณีโหลดพอร์ตเดิมค้างอยู่ เก็บ state ตัวเลือกขณะสลับหน้าใน Dashboard เมื่อ Logout ล้าง store/cache และไม่ใช้ร่วมกับบัญชีถัดไป

การทดสอบอัตโนมัติใช้ HTTP fixtures ตาม schema Backend ไม่ได้อ่าน/แก้ข้อมูลการเงินในบัญชีผู้ใช้ การยืนยันกับข้อมูลจริงต้อง Login ด้วยบัญชีของผู้ใช้บน Edge แล้วตรวจ Network/ตัวเลขเทียบเว็บ

งานเลือก PDF ที่เปิดหน้าต่างไม่ได้ยังเป็นงานค้างแยกต่างหาก รอบนี้ให้ความสำคัญกับการเชื่อมข้อมูลพอร์ตก่อนตามคำขอ
