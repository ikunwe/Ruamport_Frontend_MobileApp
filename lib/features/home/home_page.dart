import 'package:flutter/material.dart';

import 'widgets/home_logo.dart';

import '../../core/theme/app_colors.dart';
import '../auth/login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void openLogin(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }

  void showInformation(BuildContext context, String title, String description) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(color: Colors.white60, height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030603),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF101210),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const HomeLogo(),
                  Flexible(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(104, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => openLogin(context),
                      child: const FittedBox(
                        child: Text(
                          'Get started',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.05),
                    radius: .9,
                    colors: [Color(0xFF0A2310), Color(0xFF030603)],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: () => showInformation(
                                        context,
                                        'Platform',
                                        'รวมภาพการลงทุนจากหลายแพลตฟอร์มไว้ในที่เดียว\nการนำเข้าข้อมูลจริงในแอปมือถือยังอยู่ระหว่างพัฒนา',
                                      ),
                                      child: const Text('Platform'),
                                    ),
                                    TextButton(
                                      onPressed: () => showInformation(
                                        context,
                                        'Features',
                                        'ติดตามมูลค่าพอร์ต ดูสัดส่วนสินทรัพย์ และตรวจรายการลงทุนผ่าน Dashboard',
                                      ),
                                      child: const Text('Features'),
                                    ),
                                    TextButton(
                                      onPressed: () => showInformation(
                                        context,
                                        'Simulator',
                                        'เครื่องมือจำลองการลงทุนอยู่ระหว่างพัฒนา',
                                      ),
                                      child: const Text('Simulator'),
                                    ),
                                    TextButton(
                                      onPressed: () => showInformation(
                                        context,
                                        'Security',
                                        'แอปเวอร์ชันนี้เป็นตัวอย่าง UI ยังไม่ได้เชื่อมต่อบัญชีหรือข้อมูลการลงทุนจริง',
                                      ),
                                      child: const Text('Security'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lime.withValues(alpha: .04),
                                    border: Border.all(
                                      color: lime.withValues(alpha: .25),
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Text(
                                    '●  ALL YOUR INVESTMENTS. ONE VIEW.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: lime,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const HeroHeadline(),
                                const SizedBox(height: 24),
                                const Text(
                                  'บอกทุกการเปลี่ยนแปลงของสินทรัพย์และพอร์ต\nรวมทุกบัญชีลงทุนไว้ในที่เดียว',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    height: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'เปรียบเทียบผลตอบแทน วิเคราะห์พอร์ต\nและวางแผนอนาคตได้อย่างแม่นยำ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    height: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: 210,
                                  child: FilledButton(
                                    onPressed: () => openLogin(context),
                                    child: const FittedBox(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get started',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 19,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 56),
                                const Text(
                                  'รองรับหลายแพลตฟอร์มลงทุน',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                const PlatformLogos(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroHeadline extends StatelessWidget {
  const HeroHeadline({super.key});

  @override
  Widget build(BuildContext context) {
    // Scale the whole headline together so the three lines stay aligned.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '“เห็นภาพรวม'),
                TextSpan(
                  text: 'ชัดเจน',
                  style: TextStyle(color: const Color(0xFF50FF73)),
                ),
              ],
            ),
            style: _style,
          ),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                  text: 'รู้ทัน',
                  style: TextStyle(color: Color(0xFF27D9E8)),
                ),
                TextSpan(text: 'ทุกผลตอบแทน'),
              ],
            ),
            style: _style,
          ),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'เติบโต'),
                TextSpan(
                  text: 'อย่างมั่นใจ',
                  style: TextStyle(color: Color(0xFFFF8668)),
                ),
                TextSpan(text: '”'),
              ],
            ),
            style: _style,
          ),
        ],
      ),
    );
  }

  static const _style = TextStyle(
    fontSize: 40,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}

class PlatformLogos extends StatelessWidget {
  const PlatformLogos({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 15,
    runSpacing: 1,
    children: const [
      PlatformLogo('Dime!', 'Dime_logo.png'),
      PlatformLogo('InnovestX', 'InnovestX_logo.png'),
      PlatformLogo('Webull', 'Webull_logo.png'),
      PlatformLogo('Streaming', 'Streaming_logo.png'),
    ],
  );
}

class PlatformLogo extends StatelessWidget {
  const PlatformLogo(this.name, this.file, {super.key});
  final String name;
  final String file;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/$file',
    width: 120,
    height: 100,
    fit: BoxFit.contain,
    semanticLabel: name,
  );
}
