import '../models/business.dart';

class BusinessConfig {
  BusinessConfig._();

  // Match web / Supabase seed IDs
  static const drapeAndDreamId = 'a1000000-0000-4000-8000-000000000001';
  static const yourDreamCarsId = 'a1000000-0000-4000-8000-000000000002';

  static const List<Business> all = [
    Business(
      id: drapeAndDreamId,
      slug: 'drape-and-dream',
      name: 'Drape & Dream',
      businessType: BusinessType.clothing,
      description: 'Clothing billing · Gold desk',
      logoUrl: 'assets/images/drape-and-dream-logo.png',
      address: 'NIBM Clover Hills Plaza, Office No. 79, Pune',
      phone: '+91 98765 00001',
      email: 'drapedream@gmail.com',
      gstin: '27AAAAA0000A1Z5',
      pan: 'AAAAA0000A',
      isActive: true,
    ),
    Business(
      id: yourDreamCarsId,
      slug: 'your-dream-cars',
      name: 'Your Dream Cars',
      businessType: BusinessType.car,
      description: 'Car billing · Blue desk',
      logoUrl: null,
      address: 'NIBM Clover Hills Plaza, Office No. 80, Pune',
      phone: '+91 98765 00002',
      email: 'yourdreamcars1806@gmail.com',
      gstin: '27BBBBB0000B1Z5',
      pan: 'BBBBB0000B',
      isActive: true,
    ),
  ];

  static const logins = <String, ({String email, String password})>{
    'drape-and-dream': (
      email: 'drapedream@gmail.com',
      password: 'Gafru@786',
    ),
    'your-dream-cars': (
      email: 'yourdreamcars1806@gmail.com',
      password: 'Gafru@786',
    ),
  };

  static Business? findById(String id) {
    for (final business in all) {
      if (business.id == id) return business;
    }
    return null;
  }

  static Business? findBySlug(String slug) {
    for (final business in all) {
      if (business.slug == slug) return business;
    }
    return null;
  }
}
