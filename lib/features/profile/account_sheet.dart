import 'package:flutter/material.dart';
import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/user_avatar.dart';

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key, required this.account});
  final AppUser account;
  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  final form = GlobalKey<FormState>();
  late final TextEditingController username;
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool signingOut = false, hidePassword = true, hideConfirmation = true;
  String? message;
  bool saved = false;

  @override
  void initState() {
    super.initState();
    username = TextEditingController(text: widget.account.username ?? '');
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  void changed(String _) => setState(() => message = null);

  Future<void> save(AuthController auth) async {
    if (!form.currentState!.validate()) return;
    final account = auth.user ?? widget.account;
    final updateUsername =
        username.text.trim() != (account.username ?? '') ||
        !account.usernameLoginEnabled && password.text.isNotEmpty;
    if (!updateUsername && password.text.isEmpty) {
      setState(() {
        message = 'ยังไม่มีข้อมูลที่เปลี่ยนแปลง';
        saved = false;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => message = null);
    try {
      await auth.updateCredentials(
        username: updateUsername ? username.text.trim() : null,
        password: password.text.isEmpty ? null : password.text,
      );
      if (!mounted || auth.user == null) return;
      username.text = auth.user!.username ?? '';
      password.clear();
      confirmation.clear();
      setState(() {
        saved = true;
        message = 'บันทึกข้อมูลโปรไฟล์เรียบร้อยแล้ว';
      });
    } on LoginFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        saved = false;
        message = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final account = auth?.user ?? widget.account;
    final busy = auth?.savingProfile == true || signingOut;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ข้อมูลโปรไฟล์',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิดโปรไฟล์',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: UserAvatar(url: account.avatarUrl, size: 64)),
              const SizedBox(height: 22),
              TextFormField(
                key: ValueKey('name-${account.fullName}'),
                initialValue: account.fullName ?? '—',
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: username,
                enabled: !busy,
                autocorrect: false,
                onChanged: changed,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 3 ||
                      text.length > 50 ||
                      text.contains('@')) {
                    return 'Username ต้องมี 3–50 ตัวอักษร และไม่มี @';
                  }
                  return null;
                },
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: ValueKey('email-${account.email}'),
                initialValue: account.email,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    account.usernameLoginEnabled
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 16,
                    color: account.usernameLoginEnabled ? lime : Colors.white54,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      account.usernameLoginEnabled
                          ? 'เปิดใช้งาน Username/Password แล้ว'
                          : 'ตั้งรหัสผ่านเพื่อเข้าสู่ระบบด้วย Username',
                      style: TextStyle(
                        fontSize: 11,
                        color: account.usernameLoginEnabled
                            ? lime
                            : Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  account.usernameLoginEnabled
                      ? 'เปลี่ยนรหัสผ่าน'
                      : 'ตั้งรหัสผ่าน',
                  style: const TextStyle(fontSize: 13),
                ),
                children: [
                  TextFormField(
                    controller: password,
                    enabled: !busy,
                    obscureText: hidePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: changed,
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return confirmation.text.isEmpty
                            ? null
                            : 'กรุณากรอกรหัสผ่านใหม่';
                      }
                      return value!.length < 8 || value.length > 72
                          ? 'รหัสผ่านต้องมี 8–72 ตัวอักษร'
                          : null;
                    },
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่านใหม่',
                      suffixIcon: IconButton(
                        tooltip: hidePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmation,
                    enabled: !busy,
                    obscureText: hideConfirmation,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: changed,
                    validator: (value) => password.text != (value ?? '')
                        ? 'รหัสผ่านไม่ตรงกัน'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'ยืนยันรหัสผ่าน',
                      suffixIcon: IconButton(
                        tooltip: hideConfirmation
                            ? 'แสดงรหัสผ่านยืนยัน'
                            : 'ซ่อนรหัสผ่านยืนยัน',
                        onPressed: () => setState(
                          () => hideConfirmation = !hideConfirmation,
                        ),
                        icon: Icon(
                          hideConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
              const SizedBox(height: 12),
              if (message != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message!,
                    style: TextStyle(color: saved ? lime : loss, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              FilledButton(
                onPressed: busy || auth == null ? null : () => save(auth),
                child: auth?.savingProfile == true
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('บันทึกการแก้ไข'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy || auth == null
                    ? null
                    : () async {
                        setState(() => signingOut = true);
                        await auth.logout();
                        if (!context.mounted) return;
                        if (auth.hasSession) {
                          setState(() => signingOut = false);
                          return;
                        }
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                child: Text(
                  signingOut ? 'กำลังออกจากระบบ…' : 'ออกจากระบบ',
                  style: const TextStyle(color: loss),
                ),
              ),
              if (auth?.error != null)
                Text(
                  auth!.error!,
                  style: const TextStyle(color: loss, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
