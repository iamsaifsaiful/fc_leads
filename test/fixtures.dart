import 'package:fc_leads/models/business.dart';
import 'package:fc_leads/models/website_report.dart';

const noWebsite = Business(
  id: 'p1',
  name: 'Rahim Tea House',
  address: 'Road 27, Dhanmondi, Dhaka',
  category: 'Cafe',
  phone: '01711-234567',
  internationalPhone: '+880 1711-234567',
  rating: 4.4,
  reviewCount: 12,
  mapsUrl: 'https://maps.google.com/?cid=1',
  status: 'OPERATIONAL',
);

const facebookOnly = Business(
  id: 'p2',
  name: 'Lamia Boutique',
  website: 'https://www.facebook.com/lamiaboutique',
  rating: 4.8,
  reviewCount: 150,
);

const withWebsite = Business(
  id: 'p3',
  name: 'Green Leaf Dental',
  website: 'https://greenleafdental.example',
  rating: 4.7,
  reviewCount: 220,
);

const goodSite = WebsiteReport(
  url: 'https://greenleafdental.example',
  reachable: true,
  finalUrl: 'https://greenleafdental.example/',
  https: true,
  title: 'Green Leaf Dental',
  metaDescription: 'Family dentist in Gulshan',
  hasH1: true,
  mobileFriendly: true,
  structuredData: true,
  hasFaq: true,
  loadMs: 1200,
  socialLinks: {'Facebook': 'https://facebook.com/gld', 'Instagram': 'https://instagram.com/gld'},
);

const weakSite = WebsiteReport(
  url: 'http://greenleafdental.example',
  reachable: true,
  finalUrl: 'http://greenleafdental.example/',
  https: false,
  title: 'Home',
  hasH1: false,
  mobileFriendly: false,
  loadMs: 5200,
);
