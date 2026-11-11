import 'package:cloud_firestore/cloud_firestore.dart';

class WasteReportModel {
  /// Temizlenen ihbarların otomatik kaldırılma süresi
  static const Duration resolvedAutoRemoveAfter = Duration(hours: 12);

  final String id;
  final String userId;
  final String userName;
  final String wasteType;
  final double confidence;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String addressText;
  final String status; // "pending" | "resolved"
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  WasteReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.wasteType,
    required this.confidence,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.addressText,
    this.status = 'pending',
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'wasteType': wasteType,
      'confidence': confidence,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'addressText': addressText,
      'status': status,
      'resolvedBy': resolvedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory WasteReportModel.fromJson(Map<String, dynamic> json, {String? docId}) {
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

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    return WasteReportModel(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id'] as String
          : (docId ?? ''),
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      wasteType: json['wasteType'] as String? ?? 'Genel Atık',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      addressText: json['addressText'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      resolvedBy: json['resolvedBy'] as String?,
      createdAt: parseDate(json['createdAt']),
      resolvedAt: parseNullableDate(json['resolvedAt']),
    );
  }

  factory WasteReportModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WasteReportModel.fromJson(data, docId: doc.id);
  }

  DateTime? get expiresAt {
    if (status != 'resolved') return null;
    return (resolvedAt ?? createdAt).add(resolvedAutoRemoveAfter);
  }

  bool isExpiredAt(DateTime referenceTime) {
    final expiry = expiresAt;
    return expiry != null && !referenceTime.isBefore(expiry);
  }

  bool get isExpired => isExpiredAt(DateTime.now());

  WasteReportModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? wasteType,
    double? confidence,
    String? description,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? addressText,
    String? status,
    String? resolvedBy,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return WasteReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      wasteType: wasteType ?? this.wasteType,
      confidence: confidence ?? this.confidence,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressText: addressText ?? this.addressText,
      status: status ?? this.status,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

