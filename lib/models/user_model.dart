import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final String? city;
  final String? phoneNumber;
  final int ecoPoints;
  final String level;
  final int recycledCount;
  final int reportCount;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.photoUrl,
    this.bio,
    this.city,
    this.phoneNumber,
    this.ecoPoints = 0,
    this.level = 'Başlangıç',
    this.recycledCount = 0,
    this.reportCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'city': city,
      'phoneNumber': phoneNumber,
      'ecoPoints': ecoPoints,
      'level': level,
      'recycledCount': recycledCount,
      'reportCount': reportCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory UserModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    return UserModel(
      uid: (json['uid'] as String?)?.isNotEmpty == true
          ? json['uid'] as String
          : (docId ?? ''),
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      ecoPoints: (json['ecoPoints'] as num?)?.toInt() ?? 0,
      level: json['level'] as String? ?? 'Başlangıç',
      recycledCount: (json['recycledCount'] as num?)?.toInt() ?? 0,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(json['createdAt']),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromJson(data, docId: doc.id);
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? photoUrl,
    String? bio,
    String? city,
    String? phoneNumber,
    int? ecoPoints,
    String? level,
    int? recycledCount,
    int? reportCount,
    DateTime? createdAt,
    bool clearPhotoUrl = false,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      bio: bio ?? this.bio,
      city: city ?? this.city,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      level: level ?? this.level,
      recycledCount: recycledCount ?? this.recycledCount,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

