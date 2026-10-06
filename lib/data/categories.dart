import 'services.dart';

/// A kind of local business worth pitching, and what it is searched as on
/// Google Maps.
class BusinessCategory {
  const BusinessCategory(this.label, this.query, this.sector, this.services);

  final String label;

  /// Words used in the Google Maps search, e.g. "dental clinics".
  final String query;
  final String sector;

  /// The agency services this kind of business usually needs most.
  final List<AgencyService> services;
}

const _web = AgencyService.websiteDesign;
const _gfx = AgencyService.graphicsBranding;
const _reels = AgencyService.reelsVideo;
const _seo = AgencyService.seoGrowth;

/// Sectors in display order.
const sectors = [
  'Food & hospitality',
  'Health & beauty',
  'Medical',
  'Retail & shopping',
  'Property & home',
  'Education',
  'Professional services',
  'Auto & travel',
  'Events & lifestyle',
];

const categories = <BusinessCategory>[
  // Food & hospitality
  BusinessCategory('Restaurants', 'restaurants', 'Food & hospitality', [_reels, _gfx, _seo, _web]),
  BusinessCategory('Cafes & coffee shops', 'cafes', 'Food & hospitality', [_reels, _gfx, _seo]),
  BusinessCategory('Bakeries & cake shops', 'bakeries', 'Food & hospitality', [_reels, _gfx, _seo]),
  BusinessCategory('Fast food & takeaways', 'fast food restaurants', 'Food & hospitality', [_reels, _gfx, _seo]),
  BusinessCategory('Catering services', 'catering services', 'Food & hospitality', [_web, _gfx, _seo]),
  BusinessCategory('Hotels & resorts', 'hotels', 'Food & hospitality', [_web, _seo, _reels]),
  BusinessCategory('Guest houses', 'guest houses', 'Food & hospitality', [_web, _seo, _reels]),

  // Health & beauty
  BusinessCategory('Beauty salons & parlours', 'beauty salons', 'Health & beauty', [_reels, _gfx, _seo]),
  BusinessCategory('Spas & massage', 'spas', 'Health & beauty', [_web, _reels, _seo]),
  BusinessCategory('Barbershops', 'barber shops', 'Health & beauty', [_reels, _gfx, _seo]),
  BusinessCategory('Gyms & fitness centres', 'gyms', 'Health & beauty', [_reels, _web, _seo]),
  BusinessCategory('Yoga studios', 'yoga studios', 'Health & beauty', [_web, _reels, _seo]),
  BusinessCategory('Skin care & cosmetics', 'skin care clinics', 'Health & beauty', [_web, _reels, _seo]),

  // Medical
  BusinessCategory('Dental clinics', 'dental clinics', 'Medical', [_web, _seo, _gfx]),
  BusinessCategory('Medical clinics', 'medical clinics', 'Medical', [_web, _seo]),
  BusinessCategory('Diagnostic centres', 'diagnostic centers', 'Medical', [_web, _seo]),
  BusinessCategory('Physiotherapy', 'physiotherapy clinics', 'Medical', [_web, _seo, _reels]),
  BusinessCategory('Eye care & opticians', 'opticians', 'Medical', [_web, _seo, _gfx]),
  BusinessCategory('Pharmacies', 'pharmacies', 'Medical', [_seo, _gfx]),
  BusinessCategory('Veterinary clinics', 'veterinary clinics', 'Medical', [_web, _seo]),

  // Retail & shopping
  BusinessCategory('Clothing & fashion boutiques', 'clothing stores', 'Retail & shopping', [_reels, _gfx, _web]),
  BusinessCategory('Jewellery shops', 'jewelry stores', 'Retail & shopping', [_reels, _gfx, _web]),
  BusinessCategory('Shoe shops', 'shoe stores', 'Retail & shopping', [_reels, _gfx, _seo]),
  BusinessCategory('Mobile & electronics shops', 'electronics stores', 'Retail & shopping', [_web, _seo, _reels]),
  BusinessCategory('Furniture shops', 'furniture stores', 'Retail & shopping', [_web, _reels, _gfx]),
  BusinessCategory('Supermarkets & groceries', 'supermarkets', 'Retail & shopping', [_gfx, _seo]),
  BusinessCategory('Florists & gift shops', 'florists', 'Retail & shopping', [_reels, _gfx, _web]),
  BusinessCategory('Pet shops', 'pet stores', 'Retail & shopping', [_reels, _gfx, _seo]),
  BusinessCategory('Bookshops & stationery', 'book stores', 'Retail & shopping', [_gfx, _seo]),

  // Property & home
  BusinessCategory('Real estate agencies', 'real estate agencies', 'Property & home', [_web, _reels, _seo]),
  BusinessCategory('Interior designers', 'interior designers', 'Property & home', [_web, _reels, _gfx]),
  BusinessCategory('Architects', 'architects', 'Property & home', [_web, _gfx, _seo]),
  BusinessCategory('Construction companies', 'construction companies', 'Property & home', [_web, _seo, _gfx]),
  BusinessCategory('Home services & repairs', 'home repair services', 'Property & home', [_web, _seo]),
  BusinessCategory('Cleaning services', 'cleaning services', 'Property & home', [_web, _seo]),

  // Education
  BusinessCategory('Schools', 'schools', 'Education', [_web, _seo, _gfx]),
  BusinessCategory('Coaching & tuition centres', 'coaching centers', 'Education', [_web, _reels, _gfx]),
  BusinessCategory('Training institutes', 'training institutes', 'Education', [_web, _seo, _reels]),
  BusinessCategory('Language schools', 'language schools', 'Education', [_web, _seo, _reels]),
  BusinessCategory('Driving schools', 'driving schools', 'Education', [_web, _seo]),

  // Professional services
  BusinessCategory('Law firms & lawyers', 'law firms', 'Professional services', [_web, _seo, _gfx]),
  BusinessCategory('Accountants & tax advisers', 'accounting firms', 'Professional services', [_web, _seo]),
  BusinessCategory('Consultants', 'consultants', 'Professional services', [_web, _seo, _gfx]),
  BusinessCategory('Insurance agencies', 'insurance agencies', 'Professional services', [_web, _seo]),
  BusinessCategory('Printing & signage', 'printing services', 'Professional services', [_web, _seo]),
  BusinessCategory('IT & software companies', 'software companies', 'Professional services', [_seo, _gfx, _reels]),

  // Auto & travel
  BusinessCategory('Travel agencies', 'travel agencies', 'Auto & travel', [_web, _reels, _seo]),
  BusinessCategory('Car dealers', 'car dealers', 'Auto & travel', [_web, _reels, _seo]),
  BusinessCategory('Car repair & service', 'car repair', 'Auto & travel', [_web, _seo]),
  BusinessCategory('Car rental', 'car rental', 'Auto & travel', [_web, _seo]),
  BusinessCategory('Courier & logistics', 'courier services', 'Auto & travel', [_web, _seo]),

  // Events & lifestyle
  BusinessCategory('Wedding planners & event managers', 'event planners', 'Events & lifestyle', [_reels, _web, _gfx]),
  BusinessCategory('Photographers & studios', 'photography studios', 'Events & lifestyle', [_web, _seo, _reels]),
  BusinessCategory('Community centres & venues', 'event venues', 'Events & lifestyle', [_web, _reels, _seo]),
  BusinessCategory('Tailors', 'tailors', 'Events & lifestyle', [_reels, _gfx, _seo]),
];

BusinessCategory? categoryByLabel(String label) {
  for (final c in categories) {
    if (c.label == label) return c;
  }
  return null;
}
