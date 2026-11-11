import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final int ecoPoints;
  final String level;
  final int recycledCount;
  final int reportCount;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.ecoPoints = 0,
    this.level = 'Başlangıç',
    this.recycledCount = 0,
    this.reportCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'ecoPoints': ecoPoints,
      'level': level,
      'recycledCount': recycledCount,
      'reportCount': reportCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      ecoPoints: data['ecoPoints'] ?? 0,
      level: data['level'] ?? 'Başlangıç',
      recycledCount: data['recycledCount'] ?? 0,
      reportCount: data['reportCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  UserModel copyWith({
    String? fullName,
    int? ecoPoints,
    String? level,
    int? recycledCount,
    int? reportCount,
  }) {
    return UserModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      level: level ?? this.level,
      recycledCount: recycledCount ?? this.recycledCount,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt,
    );
  }
}