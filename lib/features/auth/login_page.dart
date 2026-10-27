import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import '../../core/auth/auth_scope.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/show_notice.dart';
import '../dashboard/dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

void backtoHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class _LoginPageState extends State<LoginPage> {
  bool hidden = true;
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    Future<void> login() async {
      if (auth == null || !form.currentState!.validate()) return;
      FocusScope.of(context).unfocus();
      await auth.login(username.text, password.text);
      if (mounted && auth.user != null) password.clear();
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: widget.onBack ?? () => backtoHome(context),
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
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'จัดการทุกพอร์ต และวางแผนการลงทุนในที่เดียว',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 25),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: auth?.busy == true
                          ? null
                          : () {
                              if (auth == null) {
                                notice(context, 'โหมดตัวอย่าง UI');
                                return;
                              }
                              auth.social(OAuthProvider.google);
                            },
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
                        shape: const StadiumBorder(),
                      ),
                      onPressed: auth?.busy == true
                          ? null
                          : () {
                              if (auth == null) {
                                notice(context, 'โหมดตัวอย่าง UI');
                                return;
                              }
                              auth.social(OAuthProvider.facebook);
                            },
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
                    TextFormField(
                      controller: username,
                      enabled: auth?.busy != true,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'กรุณากรอก Username';
                        if (text.length < 3 ||
                            text.length > 50 ||
                            text.contains('@')) {
                          return 'Username ต้องมี 3–50 ตัวอักษร และไม่มี @';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'กรอก Username',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: password,
                      enabled: auth?.busy != true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => login(),
                      validator: (value) => value == null || value.isEmpty
                          ? 'กรุณากรอกรหัสผ่าน'
                          : null,
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
                        onPressed: () => notice(
                          context,
                          'ยังไม่ได้เชื่อมต่อการรีเซ็ตรหัสผ่าน',
                        ),
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                    ),
                    if (auth?.error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          auth!.error!,
                          style: const TextStyle(color: loss, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      onPressed: auth?.busy == true
                          ? null
                          : auth != null
                          ? login
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const DashboardPage(),
                              ),
                            ),
                      child: auth?.busy == true
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              auth != null
                                  ? 'เข้าสู่ระบบ'
                                  : 'ดูตัวอย่าง Dashboard',
                            ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      auth == null
                          ? 'โหมดตัวอย่าง UI • ยังไม่ได้เชื่อมต่อระบบเข้าสู่ระบบ'
                          : 'ใช้บัญชีเดียวกับเว็บ · บัญชีใหม่เริ่มผ่าน Google หรือ Facebook',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
