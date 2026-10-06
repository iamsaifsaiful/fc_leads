import 'package:flutter/material.dart';

import '../models/audit.dart';
import '../models/settings.dart';
import '../theme.dart';
import 'status_pill.dart';

/// The 1080×1350 outreach graphic (Instagram 4:5), personalised for one
/// business. Laid out at exactly that size in logical pixels; show it
/// inside a FittedBox and capture it with GraphicRenderer.
class AuditGraphic extends StatelessWidget {
  const AuditGraphic({
    super.key,
    required this.clientName,
    required this.items,
    required this.settings,
  });

  static const width = 1080.0;
  static const height = 1350.0;

  final String clientName;
  final List<AuditItem> items;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final agency = settings.agencyName.trim().isEmpty ? 'FansConnector' : settings.agencyName.trim();
    final contact = [
      if (settings.agencyWebsite.trim().isNotEmpty) settings.agencyWebsite.trim(),
      if (settings.whatsapp.trim().isNotEmpty) 'WhatsApp: ${settings.whatsapp.trim()}',
    ].join('   ·   ');

    return SizedBox(
      width: width,
      height: height,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: Brand.body, color: Brand.cream, fontSize: 24),
        child: ClipRect(
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Brand.navy)),
              const Positioned(right: -180, top: -180, child: _Ring(size: 520, alpha: 0x40)),
              const Positioned(right: -90, top: -90, child: _Ring(size: 340, alpha: 0x66)),
              Positioned(
                right: 40,
                top: 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(color: Brand.gold, shape: BoxShape.circle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(80, 72, 80, 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(agency: agency),
                    const SizedBox(height: 36),
                    const Expanded(child: _Headline()),
                    const SizedBox(height: 32),
                    _AuditCard(clientName: clientName, items: items),
                    const SizedBox(height: 40),
                    _Footer(contact: contact),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});
  final double size;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Brand.gold.withAlpha(alpha), width: 2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.agency});
  final String agency;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(12)),
            child: Text(
              agency.characters.first.toUpperCase(),
              style: const TextStyle(
                fontFamily: Brand.display,
                fontWeight: FontWeight.w800,
                fontSize: 30,
                color: Brand.navy,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              agency,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 32),
            ),
          ),
          // Leaves room for the gold dot in the corner.
          const SizedBox(width: 120),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    // Scales down instead of overflowing if a font renders wider.
    return const FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 920,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FREE DIGITAL AUDIT',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: 3, color: Brand.gold),
            ),
            SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Customers are looking.\n'),
                  TextSpan(text: 'Are they finding you?', style: TextStyle(color: Brand.gold)),
                ],
              ),
              style: TextStyle(
                fontFamily: Brand.display,
                fontWeight: FontWeight.w800,
                fontSize: 88,
                height: 1.02,
                letterSpacing: -2,
                color: Brand.cream,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Your business is on Google Maps. But how visible are you on your '
              'website, social media, Google Search and in AI answers? We checked.',
              style: TextStyle(fontSize: 29, height: 1.4, color: Brand.mist),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.clientName, required this.items});
  final String clientName;
  final List<AuditItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(44, 36, 44, 30),
      decoration: BoxDecoration(color: Brand.cream, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Brand.creamLine, width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Brand.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 34,
                      color: Brand.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Online presence', style: TextStyle(fontSize: 22, color: Brand.muted)),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _AuditRow(item: items[i], last: i == items.length - 1),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.item, required this.last});
  final AuditItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Brand.creamRow)),
      ),
      child: Row(
        children: [
          Icon(areaIcon(item.area), size: 34, color: Brand.navy),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              item.area.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Brand.navy),
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(
            status: item.status,
            text: item.verdict,
            fontSize: 22,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.contact});
  final String contact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Full report & fix plan, free',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: Brand.display, fontWeight: FontWeight.w700, fontSize: 34),
              ),
              if (contact.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 24, color: Brand.mist),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
          decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(18)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Message us',
                style: TextStyle(
                  fontFamily: Brand.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  color: Brand.navy,
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward, size: 30, color: Brand.navy),
            ],
          ),
        ),
      ],
    );
  }
}
