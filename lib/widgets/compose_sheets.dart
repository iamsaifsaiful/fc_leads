import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/phone.dart';
import '../theme.dart';

/// Bottom sheet for WhatsApp: edit the message, then hand it to WhatsApp
/// in two taps. WhatsApp never lets another app press Send, so each step
/// opens WhatsApp and the user taps Send there.
class WhatsAppSheet extends StatefulWidget {
  const WhatsAppSheet({
    super.key,
    required this.phone,
    required this.text,
    required this.templateText,
    required this.onOpenChat,
    required this.onSendGraphic,
    required this.onChanged,
  });

  final String phone;
  final String text;

  /// The message as the template makes it, for "Reset".
  final String templateText;

  /// Opens the chat with the message typed in. Returns true if WhatsApp opened.
  final Future<bool> Function(String phone, String text) onOpenChat;

  /// Sends the graphic to the chat, with an optional caption.
  final Future<bool> Function(String phone, String caption) onSendGraphic;

  /// Called with the edited phone and text so they can be saved.
  final void Function(String phone, String text) onChanged;

  @override
  State<WhatsAppSheet> createState() => _WhatsAppSheetState();
}

class _WhatsAppSheetState extends State<WhatsAppSheet> {
  late final _phone = TextEditingController(text: widget.phone);
  late final _text = TextEditingController(text: widget.text);
  bool _chatDone = false;
  bool _graphicDone = false;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _text.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  void _changed() => widget.onChanged(_phone.text.trim(), _text.text);

  Future<void> _run(Future<bool> Function() action, void Function() done) async {
    if (_digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a WhatsApp number first.')));
      return;
    }
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) done();
    });
  }

  @override
  Widget build(BuildContext context) {
    final landline = _digits.isNotEmpty && !looksLikeMobile(_digits);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Send on WhatsApp', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 6),
            const Text(
              'WhatsApp does not let any app press Send for you. Each step opens their chat: '
              'tap Send in WhatsApp, then come back for the next step.',
              style: TextStyle(color: Brand.muted, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) {
                setState(() {});
                _changed();
              },
              decoration: InputDecoration(
                labelText: 'WhatsApp number with country code',
                helperText: landline ? 'Looks like a landline. It may not have WhatsApp.' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 14,
              onChanged: (_) => _changed(),
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() => _text.text = widget.templateText);
                    _changed();
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset to template'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _text.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            _StepButton(
              number: 1,
              done: _chatDone,
              label: 'Open chat with this message',
              filled: true,
              onPressed: _busy
                  ? null
                  : () => _run(() => widget.onOpenChat(_digits, _text.text), () => _chatDone = true),
            ),
            const SizedBox(height: 10),
            _StepButton(
              number: 2,
              done: _graphicDone,
              label: 'Send the graphic',
              filled: false,
              onPressed: _busy
                  ? null
                  : () => _run(() => widget.onSendGraphic(_digits, ''), () => _graphicDone = true),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => widget.onSendGraphic(_digits, _text.text), () {
                        _chatDone = true;
                        _graphicDone = true;
                      }),
              child: const Text('Or send both at once (graphic with the message as caption)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for email: edit recipient, subject and body, then open
/// the email app with the graphic attached.
class EmailSheet extends StatefulWidget {
  const EmailSheet({
    super.key,
    required this.to,
    required this.subject,
    required this.body,
    required this.templateSubject,
    required this.templateBody,
    required this.onSend,
    required this.onChanged,
  });

  final String to;
  final String subject;
  final String body;
  final String templateSubject;
  final String templateBody;
  final Future<bool> Function(String to, String subject, String body) onSend;
  final void Function(String to, String subject, String body) onChanged;

  @override
  State<EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<EmailSheet> {
  late final _to = TextEditingController(text: widget.to);
  late final _subject = TextEditingController(text: widget.subject);
  late final _body = TextEditingController(text: widget.body);
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() => widget.onChanged(_to.text.trim(), _subject.text, _body.text);

  Future<void> _send() async {
    setState(() => _busy = true);
    final ok = await widget.onSend(_to.text.trim(), _subject.text, _body.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok || _done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Send by email', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 6),
            const Text(
              'Opens your email app with everything filled in and the graphic attached. Tap Send there.',
              style: TextStyle(color: Brand.muted, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _to,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _changed(),
              decoration: const InputDecoration(labelText: 'To'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subject,
              onChanged: (_) => _changed(),
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 8,
              maxLines: 16,
              onChanged: (_) => _changed(),
              decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _subject.text = widget.templateSubject;
                    _body.text = widget.templateBody;
                  });
                  _changed();
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset to template'),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: Icon(_done ? Icons.check : Icons.mail_outline),
              label: Text(_done ? 'Opened. Open again' : 'Open email app'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.number,
    required this.done,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final int number;
  final bool done;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: done ? const Color(0xFF2E8B57) : Brand.gold,
          child: done
              ? const Icon(Icons.check, size: 16, color: Brand.white)
              : Text('$number', style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
    return filled
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}
