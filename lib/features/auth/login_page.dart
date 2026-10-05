import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/show_notice.dart';
import '../dashboard/dashboard_page.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

void BacktoHome(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const HomePage()));
}

class _LoginPageState extends State<LoginPage> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => BacktoHome(context),
                    icon: Icon(Icons.arrow_back),
                  ),
                ),
                const SizedBox(height: 25),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/branding/ruamport_icon.png',
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        excludeFromSemantics: true,
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 10),
                      SvgPicture.asset(
                        'assets/branding/text_Ruamport.svg',
                        width: 130,
                        excludeFromSemantics: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 38),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/Wallpaper.jpg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black45,
                        BlendMode.darken,
                      ),
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF173329), Color(0xFF0C1410)],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ONE PORTFOLIO. CLEARER FUTURE.',
                          style: TextStyle(
                            color: lime,
                            fontSize: 10,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'มองเห็นทุกการลงทุน\nได้จากที่เดียว',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'เข้าสู่ระบบ',
                  style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'จัดการทุกพอร์ต และวางแผนการลงทุนในที่เดียว',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 25),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () =>
                      notice(context, 'ยังไม่ได้เชื่อมต่อ Google ในแอปมือถือ'),
                  icon: SvgPicture.asset(
                    'assets/branding/google.svg',
                    width: 15,
                    height: 15,
                    excludeFromSemantics: true,
                  ),
                  label: const Text('เข้าสู่ระบบด้วย Google'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => notice(
                    context,
                    'ยังไม่ได้เชื่อมต่อ Facebook ในแอปมือถือ',
                  ),
                  icon: const Icon(Icons.facebook),
                  label: const Text('เข้าสู่ระบบด้วย Facebook'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          'หรือ',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'กรอก Username',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  obscureText: hidden,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        notice(context, 'ยังไม่ได้เชื่อมต่อการรีเซ็ตรหัสผ่าน'),
                    child: const Text('ลืมรหัสผ่าน?'),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DashboardPage(),
                    ),
                  ),
                  child: const Text('ดูตัวอย่าง Dashboard'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'โหมดตัวอย่าง UI • ยังไม่ได้เชื่อมต่อระบบเข้าสู่ระบบ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
