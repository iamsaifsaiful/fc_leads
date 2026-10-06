import 'package:fc_leads/logic/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the international number when there is one', () {
    expect(whatsappNumber(international: '+880 1711-234567'), '8801711234567');
  });

  test('turns a local Bangladeshi number into 880 format', () {
    expect(whatsappNumber(national: '01711-234567'), '8801711234567');
    expect(whatsappNumber(national: '+8801711234567'), '8801711234567');
    expect(whatsappNumber(national: '008801711234567'), '8801711234567');
  });

  test('returns nothing for missing or short numbers', () {
    expect(whatsappNumber(), '');
    expect(whatsappNumber(national: '123'), '');
  });

  test('spots Bangladeshi landlines', () {
    expect(looksLikeMobile('8801711234567'), isTrue);
    expect(looksLikeMobile('88029612345'), isFalse);
    expect(looksLikeMobile('447700900123'), isTrue);
  });
}
