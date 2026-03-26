import 'package:equatable/equatable.dart';

class DebtCustomer extends Equatable {
  const DebtCustomer({
    this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DebtCustomer.fromMap(Map<String, Object?> map) => DebtCustomer(
    id: map['id'] as int?,
    name: map['name'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    address: map['address'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    createdAt:
        map['created_at'] == null
            ? null
            : DateTime.tryParse(map['created_at'] as String),
    updatedAt:
        map['updated_at'] == null
            ? null
            : DateTime.tryParse(map['updated_at'] as String),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'notes': notes,
  };

  DebtCustomer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DebtCustomer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [id, name, phone, address, notes, createdAt, updatedAt];
}
