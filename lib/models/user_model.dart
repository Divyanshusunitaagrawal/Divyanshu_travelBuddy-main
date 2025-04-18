import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? profilePic;
  final String? bio;
  final String? phone;
  final String? interest;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final DateTime? lastLocationUpdate;
  double? distance; // Optional field for nearby users
  
  UserModel({
    required this.id,
    this.name,
    this.email,
    this.profilePic,
    this.bio,
    this.phone,
    this.interest,
    this.isActive = false,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.distance,
  });
  
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'],
      email: map['email'],
      profilePic: map['profilePic'],
      bio: map['bio'],
      phone: map['phone'],
      interest: map['interest'],
      isActive: map['isActive'] ?? false,
      latitude: map['latitude'],
      longitude: map['longitude'],
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? (map['lastLocationUpdate'] as Timestamp).toDate()
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'profilePic': profilePic,
      'bio': bio,
      'phone': phone,
      'interest': interest,
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'lastLocationUpdate': lastLocationUpdate,
    };
  }
  
  UserModel copyWith({
    String? name,
    String? email,
    String? profilePic,
    String? bio,
    String? phone,
    String? interest,
    bool? isActive,
    double? latitude,
    double? longitude,
    DateTime? lastLocationUpdate,
    double? distance,
  }) {
    return UserModel(
      id: this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePic: profilePic ?? this.profilePic,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      interest: interest ?? this.interest,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      distance: distance ?? this.distance,
    );
  }
}