import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';

class RecoveryKeyEscrowService {
  RecoveryKeyEscrowService({
    FirebaseAuth? auth,
    http.Client? client,
    String? backendUrl,
  }) : this._(
         auth,
         client ?? http.Client(),
         backendUrl ?? AppConfig.recoveryBackendUrl,
       );

  RecoveryKeyEscrowService._(this._auth, this._client, this._backendUrl);

  final FirebaseAuth? _auth;
  final http.Client _client;
  final String _backendUrl;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  Future<void> backupKey({
    required String userId,
    required String recoveryKey,
    required int keyVersion,
    required String escrowId,
  }) async {
    await _post(
      userId: userId,
      path: '/v1/recovery-key/escrow',
      body: <String, Object?>{
        'recoveryKey': recoveryKey,
        'keyVersion': keyVersion,
        'escrowId': escrowId,
      },
    );
  }

  Future<String> sendRecoveryEmail({required String userId}) async {
    final response = await _post(
      userId: userId,
      path: '/v1/recovery-key/email',
      body: const <String, Object?>{},
    );
    return response['email']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> _post({
    required String userId,
    required String path,
    required Map<String, Object?> body,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.uid != userId) {
      throw const RecoveryKeyEscrowException('authentication_required');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const RecoveryKeyEscrowException('authentication_required');
    }
    final origin = _backendUrl.replaceAll(RegExp(r'/+$'), '');
    final response = await _client
        .post(
          Uri.parse('$origin$path'),
          headers: <String, String>{
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> json = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Preserve the HTTP status as the useful failure signal.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecoveryKeyEscrowException(
        json['error']?.toString() ?? 'recovery_service_unavailable',
      );
    }
    return json;
  }
}

class RecoveryKeyEscrowException implements Exception {
  const RecoveryKeyEscrowException(this.code);

  final String code;

  @override
  String toString() => code;
}
