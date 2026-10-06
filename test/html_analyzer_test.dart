import 'package:fc_leads/logic/html_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

const _html = '''
<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>  Green Leaf
  Dental &amp; Care </title>
<meta content="Family dentist in Gulshan" name="description">
<script type="application/ld+json">{"@type":"Dentist"}</script>
</head><body>
<h1 class="hero">Smile</h1>
<a href="https://www.facebook.com/greenleaf">Facebook</a>
<a href="https://www.facebook.com/sharer/sharer.php?u=x">Share</a>
<a href='https://instagram.com/greenleaf/'>IG</a>
<a href="https://wa.me/8801711234567">WhatsApp</a>
<a href="mailto:hello@greenleaf.com.bd?subject=Hi">Email us</a>
<img src="logo@2x.png">
<p>Write to info@greenleaf.com.bd. Frequently asked questions below.</p>
</body></html>
''';

void main() {
  test('reads title, description, viewport, H1 and schema', () {
    final r = analyzeHtml(_html, url: 'greenleaf.com.bd', finalUrl: 'https://greenleaf.com.bd/', loadMs: 900);
    expect(r.reachable, isTrue);
    expect(r.https, isTrue);
    expect(r.title, 'Green Leaf Dental & Care');
    expect(r.metaDescription, 'Family dentist in Gulshan');
    expect(r.mobileFriendly, isTrue);
    expect(r.hasH1, isTrue);
    expect(r.structuredData, isTrue);
    expect(r.hasFaq, isTrue);
    expect(r.seoPassed, 5);
  });

  test('finds profile links but skips share buttons', () {
    final r = analyzeHtml(_html, url: 'x', finalUrl: 'https://x/', loadMs: 0);
    expect(r.socialLinks.keys, ['Facebook', 'Instagram', 'WhatsApp']);
    expect(r.socialLinks['Facebook'], 'https://www.facebook.com/greenleaf');
  });

  test('finds real emails and ignores image file names', () {
    final r = analyzeHtml(_html, url: 'x', finalUrl: 'https://x/', loadMs: 0);
    expect(r.emails, ['hello@greenleaf.com.bd', 'info@greenleaf.com.bd']);
  });

  test('bare page fails the checks', () {
    final r = analyzeHtml('<html><body>Hi</body></html>', url: 'x', finalUrl: 'http://x/', loadMs: 0);
    expect(r.seoPassed, 0);
    expect(r.socialLinks, isEmpty);
    expect(r.emails, isEmpty);
  });

  test('recognises social profile addresses', () {
    expect(socialPlatformOf('https://m.facebook.com/shop'), 'Facebook');
    expect(socialPlatformOf('instagram.com/shop'), 'Instagram');
    expect(socialPlatformOf('https://notfacebook.com'), isNull);
    expect(socialPlatformOf('https://example.com'), isNull);
  });
}
