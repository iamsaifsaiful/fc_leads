import 'package:fc_leads/logic/audit_builder.dart';
import 'package:fc_leads/logic/messages.dart';
import 'package:fc_leads/models/settings.dart';
import 'package:fc_leads/widgets/audit_graphic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  testWidgets('graphic uses the agency details from Settings', (tester) async {
    const settings = AppSettings(
      agencyName: 'Nova Studio',
      agencyWebsite: 'novastudio.com',
      whatsapp: '+880 1800-000000',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FittedBox(
          child: AuditGraphic(
            clientName: 'A Very Long Restaurant Name That Keeps Going And Going',
            items: buildAudit(noWebsite, null),
            settings: settings,
          ),
        ),
      ),
    ));

    expect(find.text('Nova Studio'), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
    expect(find.text('novastudio.com   ·   WhatsApp: +880 1800-000000'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);
    // Laid out at full size without overflowing.
    expect(tester.getSize(find.byType(AuditGraphic)), const Size(1080, 1350));
    expect(tester.takeException(), isNull);
  });

  test('email signature includes the agency email', () {
    const s = AppSettings(agencyName: 'Nova Studio', email: 'hi@novastudio.com');
    final m = emailMessage(noWebsite, buildAudit(noWebsite, null), s);
    expect(m.body, endsWith('Nova Studio\nfansconnector.com\nhi@novastudio.com'));
  });
}
