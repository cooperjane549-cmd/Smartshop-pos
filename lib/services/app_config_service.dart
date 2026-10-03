import 'package:cloud_firestore/cloud_firestore.dart';

/// Fetches app-wide configuration (contact details, Terms & Conditions)
/// from Firestore, so none of it is hardcoded and can be updated by the
/// owner without an app release.
class AppConfigService {
  static final AppConfigService instance = AppConfigService._internal();
  AppConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference get _configDocRef =>
      _firestore.collection('app_config').doc('general');

  Future<AppConfig> getConfig() async {
    final doc = await _configDocRef.get();
    if (!doc.exists) {
      return AppConfig.empty();
    }
    final data = doc.data() as Map<String, dynamic>;
    return AppConfig(
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      contactWhatsapp: data['contactWhatsapp'] ?? '',
      termsAndConditions: data['termsAndConditions'] ?? '',
      termsLastUpdated: data['termsLastUpdated'] ?? '',
    );
  }

  /// Live stream version, in case the Dashboard wants to reflect changes
  /// without requiring the user to reopen the app.
  Stream<AppConfig> watchConfig() {
    return _configDocRef.snapshots().map((doc) {
      if (!doc.exists) return AppConfig.empty();
      final data = doc.data() as Map<String, dynamic>;
      return AppConfig(
        contactEmail: data['contactEmail'] ?? '',
        contactPhone: data['contactPhone'] ?? '',
        contactWhatsapp: data['contactWhatsapp'] ?? '',
        termsAndConditions: data['termsAndConditions'] ?? '',
        termsLastUpdated: data['termsLastUpdated'] ?? '',
      );
    });
  }
}

class AppConfig {
  final String contactEmail;
  final String contactPhone;
  final String contactWhatsapp;
  final String termsAndConditions;
  final String termsLastUpdated;

  AppConfig({
    required this.contactEmail,
    required this.contactPhone,
    required this.contactWhatsapp,
    required this.termsAndConditions,
    required this.termsLastUpdated,
  });

  factory AppConfig.empty() => AppConfig(
        contactEmail: '',
        contactPhone: '',
        contactWhatsapp: '',
        termsAndConditions: '',
        termsLastUpdated: '',
      );
}
