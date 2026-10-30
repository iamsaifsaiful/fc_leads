import 'package:flutter/material.dart';

import '../logic/billing.dart';
import '../logic/lead_filter.dart';
import '../services/server.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'templates_screen.dart';

/// Everything that isn't a daily screen: templates, settings, exports, help.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  Future<void> _exportLeads(BuildContext context) async {
    final leads = await services.leads.all();
    if (leads.isEmpty) {
      if (context.mounted) _toast(context, 'No leads to export yet');
      return;
    }
    final path = await services.renderer.writeExport('fc_leads_all.csv', leadsToCsv(leads));
    await services.share.shareFile(path: path, mimeType: 'text/csv', subject: 'FC Leads export');
  }

  Future<void> _exportClients(BuildContext context) async {
    final clients = await services.clients.all();
    if (clients.isEmpty) {
      if (context.mounted) _toast(context, 'No clients to export yet');
      return;
    }
    final path = await services.renderer.writeExport('fc_clients.csv', clientsToCsv(clients));
    await services.share.shareFile(path: path, mimeType: 'text/csv', subject: 'FC Leads clients');
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your leads stay saved on the website.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.sync.flush();
    } catch (_) {}
    await services.session.logout();
  }

  void _toast(BuildContext context, String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
          child: ListTile(
            leading: Icon(icon, color: Brand.navy),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _AccountCard(services: services),
          const SizedBox(height: 12),
          tile(
            Icons.edit_note,
            'Message templates',
            'Outreach WhatsApp, email and payment reminder',
            () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => TemplatesScreen(settings: settings),
            )),
          ),
          const SizedBox(height: 8),
          tile(
            Icons.settings_outlined,
            'Settings',
            'Agency details, reminders, billing, graphic colour',
            () => openSettings(context, settings, services),
          ),
          const SizedBox(height: 8),
          tile(Icons.table_view_outlined, 'Export leads (CSV)', 'Open in Excel or Google Sheets', () => _exportLeads(context)),
          const SizedBox(height: 8),
          tile(Icons.request_quote_outlined, 'Export clients (CSV)', 'Fees, due dates and payment status', () => _exportClients(context)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFF9F1C14)),
              title: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF9F1C14))),
              subtitle: const Text('Unsent work is sent first'),
              onTap: () => _signOut(context),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Help', style: TextStyle(fontFamily: Brand.ui, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '• Pull down on any list to refresh it.\n'
                '• Leads: set a follow-up date and you get a reminder that morning.\n'
                '• Clients: set the monthly fee and due day. On the due day you get a reminder; '
                'tap it to send a payment message.\n'
                '• WhatsApp and email apps never let another app press Send, so you always tap Send there.\n'
                '• Reminder time and payment details are in Settings.',
                style: TextStyle(height: 1.5, color: Brand.ink),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'FC Leads by FansConnector. City data: GeoNames (CC BY 4.0). Business data: Google Maps Platform.',
            style: TextStyle(color: Brand.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final session = services.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final u = session.user;
        if (u == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Brand.gold,
                    child: Text(u.initials, style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name, style: const TextStyle(color: Brand.white, fontWeight: FontWeight.w800, fontSize: 17)),
                        Text(u.email, style: const TextStyle(color: Brand.mist, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                    child: Text(u.canManage ? 'Admin' : 'Team',
                        style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Connected to $serverHost', style: const TextStyle(color: Brand.mist, fontSize: 12.5)),
              if (u.canManage) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Brand.white, side: const BorderSide(color: Brand.mist)),
                  onPressed: () => session.setAdminView(true),
                  icon: const Icon(Icons.insights, color: Brand.gold),
                  label: const Text('Back to admin'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
