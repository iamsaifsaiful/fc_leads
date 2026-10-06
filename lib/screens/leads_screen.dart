import 'package:flutter/material.dart';

import '../models/audit.dart';
import '../models/lead.dart';
import '../services/settings_controller.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'lead_screen.dart';

/// Every business the user has opened, newest first.
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key, required this.settings, required this.services});

  final SettingsController settings;
  final AppServices services;

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  List<Lead>? _leads;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final leads = await widget.services.leads.all();
    if (mounted) setState(() => _leads = leads);
  }

  Future<void> _open(Lead lead) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LeadScreen(
        business: lead.business,
        settings: widget.settings,
        services: widget.services,
      ),
    ));
    await _reload();
  }

  Future<void> _remove(Lead lead) async {
    // Take it out of the list right away: a dismissed row must leave the tree.
    setState(() => _leads = [...?_leads]..remove(lead));
    await widget.services.leads.remove(lead.business.id);
  }

  @override
  Widget build(BuildContext context) {
    final leads = _leads;
    final contacted = leads?.where((l) => l.contacted).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Leads')),
      body: leads == null
          ? const Center(child: CircularProgressIndicator())
          : leads.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Businesses you open from Search are saved here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Brand.muted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${leads.length} saved · $contacted contacted',
                        style: const TextStyle(color: Brand.muted),
                      ),
                    ),
                    for (final lead in leads) ...[
                      Dismissible(
                        key: ValueKey(lead.business.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6D2C9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_outline, color: Color(0xFF8A2412)),
                        ),
                        onDismissed: (_) => _remove(lead),
                        child: _LeadTile(lead: lead, onTap: () => _open(lead)),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.lead, required this.onTap});
  final Lead lead;
  final VoidCallback onTap;

  String _date(DateTime d) => '${d.day}/${d.month}';

  @override
  Widget build(BuildContext context) {
    final issues = lead.items.where((i) => i.status != AuditStatus.good).length;
    final sent = [
      if (lead.whatsappSentAt != null) 'WhatsApp ${_date(lead.whatsappSentAt!)}',
      if (lead.emailSentAt != null) 'Email ${_date(lead.emailSentAt!)}',
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sent.isEmpty ? 'Not contacted yet' : 'Sent: ${sent.join(' · ')}',
                      style: TextStyle(color: sent.isEmpty ? Brand.muted : const Color(0xFF1D5230)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                issues == 0 ? 'All good' : '$issues to fix',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
