import 'package:flutter/material.dart';

import '../logic/billing.dart';
import '../logic/lead_filter.dart';
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
            'Agency details, reminders, API key, graphic colour',
            () => openSettings(context, settings, services),
          ),
          const SizedBox(height: 8),
          tile(Icons.table_view_outlined, 'Export leads (CSV)', 'Open in Excel or Google Sheets', () => _exportLeads(context)),
          const SizedBox(height: 8),
          tile(Icons.request_quote_outlined, 'Export clients (CSV)', 'Fees, due dates and payment status', () => _exportClients(context)),
          const SizedBox(height: 20),
          const Text('Help', style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w800, fontSize: 18)),
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
