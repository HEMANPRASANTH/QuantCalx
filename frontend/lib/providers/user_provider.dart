import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String avatarPath; // local file path or ''

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.avatarPath = '',
  });

  UserProfile copyWith({String? name, String? email, String? phone, String? avatarPath}) =>
    UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
    );

  // Deterministic "wallet hash" — SHA-256 of name+email (blockchain feel)
  String get walletHash {
    final data = utf8.encode('$name|$email|QUANTCALX');
    return sha256.convert(data).toString().substring(0, 40);
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'QC';
  }
}

class UserProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _onboarded = false;

  UserProfile? get profile => _profile;
  bool get onboarded => _onboarded;

  UserProvider() { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _onboarded = p.getBool('onboarded') ?? false;
    if (_onboarded) {
      _profile = UserProfile(
        name: p.getString('name') ?? '',
        email: p.getString('email') ?? '',
        phone: p.getString('phone') ?? '',
        avatarPath: p.getString('avatarPath') ?? '',
      );
    }
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile prof) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('name', prof.name);
    await p.setString('email', prof.email);
    await p.setString('phone', prof.phone);
    await p.setString('avatarPath', prof.avatarPath);
    await p.setBool('onboarded', true);
    _profile = prof;
    _onboarded = true;
    notifyListeners();
  }

  Future<void> updateAvatar(String path) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(avatarPath: path);
    final p = await SharedPreferences.getInstance();
    await p.setString('avatarPath', path);
    notifyListeners();
  }
}
