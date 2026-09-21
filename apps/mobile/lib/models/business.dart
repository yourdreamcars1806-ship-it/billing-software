import 'package:equatable/equatable.dart';

enum BusinessType { clothing, car }

class Business extends Equatable {
  const Business({
    required this.id,
    required this.slug,
    required this.name,
    required this.businessType,
    this.description,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String name;
  final BusinessType businessType;
  final String? description;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;
  final bool isActive;

  bool get isClothing => businessType == BusinessType.clothing;
  bool get isCar => businessType == BusinessType.car;

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      businessType: _parseBusinessType(json['business_type'] as String?),
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      gstin: json['gstin'] as String?,
      pan: json['pan'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'business_type': businessType.name,
        'description': description,
        'logo_url': logoUrl,
        'address': address,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'pan': pan,
        'is_active': isActive,
      };

  static BusinessType _parseBusinessType(String? value) {
    switch (value) {
      case 'car':
        return BusinessType.car;
      case 'clothing':
      default:
        return BusinessType.clothing;
    }
  }

  @override
  List<Object?> get props => [id, slug, name, businessType, isActive];
}
