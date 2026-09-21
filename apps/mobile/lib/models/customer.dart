import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    this.mobile,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String businessId;
  final String name;
  final String? mobile;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: (json['id'] as String?) ?? '',
      businessId: (json['business_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Customer',
      mobile: json['mobile'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'name': name,
        'mobile': mobile,
        'email': email,
        'address': address,
        'notes': notes,
        'is_active': isActive,
      };

  Customer copyWith({
    String? id,
    String? businessId,
    String? name,
    String? mobile,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, businessId, name, mobile, isActive];
}
