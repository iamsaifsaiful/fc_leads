import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/server.dart';
import '../services/session.dart';
import '../theme.dart';

/// Sign in as a team member or as an admin. The app only works with the
/// agency's own website.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final SessionController session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  LoginRole _role = LoginRole.team;
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.session.expired) _error = 'Your session ended. Please sign in again.';
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email or username and password.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.login(_login.text, _password.text, _role);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _segment(String label, LoginRole role) {
    final on = _role == role;
    return Expanded(
      child: Semantics(
        selected: on,
        button: true,
        child: Material(
          color: on ? Brand.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          elevation: on ? 1 : 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => setState(() {
              _role = role;
              _error = null;
            }),
            child: SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15,
                    color: on ? const Color(0xFF0B1220) : const Color(0xFF5B6472),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = _role == LoginRole.admin;
    return Scaffold(
      backgroundColor: Brand.navy,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(16)),
                          child: const Text('F', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Brand.navy)),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'FC Leads',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Brand.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Find, audit and win local clients.\nby FansConnector',
                          style: TextStyle(fontSize: 15, height: 1.5, color: Brand.mist),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 230),
                    decoration: const BoxDecoration(
                      color: Brand.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 26, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [_segment('Team', LoginRole.team), const SizedBox(width: 4), _segment('Admin', LoginRole.admin)]),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            admin ? 'Admin sign in' : 'Welcome back',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            admin
                                ? 'See what your team did today, this week and this month.'
                                : 'Sign in with the team login your admin gave you.',
                            style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF5B6472)),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _login,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email or username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _password,
                            obscureText: !_show,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _show ? 'Hide password' : 'Show password',
                                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _show = !_show),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => launchUrl(
                                Uri.parse('$serverBase/wp-login.php?action=lostpassword'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFFDE4E1), borderRadius: BorderRadius.circular(12)),
                              child: Text(_error!, style: const TextStyle(color: Color(0xFF9F1C14), fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.white))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(admin ? 'Sign in as admin' : 'Sign in'),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.arrow_forward, color: Brand.gold, size: 20),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF5B6472)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    admin
                                        ? 'Use your admin account on $serverHost. Team members cannot open reports.'
                                        : 'Connected to $serverHost. Your work syncs there so your admin can see your progress.',
                                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF4B5563)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
