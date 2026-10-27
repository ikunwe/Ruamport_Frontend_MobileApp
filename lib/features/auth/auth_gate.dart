import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../home/home_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});
  final AuthController auth;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool authenticated = false;
  bool showLogin = false;
  @override
  void initState() {
    super.initState();
    authenticated = widget.auth.user != null;
    widget.auth.addListener(changed);
  }

  void changed() {
    if (!mounted) return;
    final next = widget.auth.user != null;
    if (authenticated && !next) showLogin = true;
    if (next) showLogin = false;
    if (next != authenticated ||
        widget.auth.hasSession && widget.auth.profileError != null) {
      authenticated = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    if (auth.restoring && auth.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.hasSession && auth.profileError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 38),
                  const SizedBox(height: 16),
                  Text(auth.profileError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.loadProfile,
                    child: const Text('ลองโหลดข้อมูลผู้ใช้อีกครั้ง'),
                  ),
                  TextButton(
                    onPressed: auth.logout,
                    child: const Text('กลับไปเข้าสู่ระบบ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return auth.user != null
        ? DashboardPage(account: auth.user)
        : showLogin
        ? LoginPage(onBack: () => setState(() => showLogin = false))
        : const HomePage();
  }
}
