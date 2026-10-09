import 'package:cloud_firestore/cloud_firestore.dart';

class Hospital {
  final String id;
  final String name;
  final String district;
  final String address;
  final String phone;

  const Hospital({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    this.phone = '',
  });

  factory Hospital.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Hospital(
      id: doc.id,
      name: d['name'] ?? '',
      district: d['district'] ?? '',
      address: d['address'] ?? '',
      phone: d['phone'] ?? '',
    );
  }

  /// The 25 districts of Sri Lanka, used by the hospital form.
  static const districts = [
    'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle', 'Gampaha', 'Hambantota',
    'Jaffna', 'Kalutara', 'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar', 'Matale',
    'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya', 'Polonnaruwa', 'Puttalam', 'Ratnapura',
    'Trincomalee', 'Vavuniya',
  ];
}
