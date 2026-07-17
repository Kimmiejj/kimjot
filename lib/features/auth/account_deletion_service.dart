import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';

class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    http.Client? client,
    String? backendUrl,
  }) : this._(
         auth,
         client ?? http.Client(),
         backendUrl ?? AppConfig.recoveryBackendUrl,
       );

  AccountDeletionService._(this._auth, this._client, this._backendUrl);

  final FirebaseAuth? _auth;
  final http.Client _client;
  final String _backendUrl;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  Future<void> deleteAccount(String userId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.uid != userId) {
      throw const AccountDeletionException('authentication_required');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const AccountDeletionException('authentication_required');
    }

    final origin = _backendUrl.replaceAll(RegExp(r'/+$'), '');
    late final http.Response response;
    try {
      response = await _client
          .delete(
            Uri.parse('$origin/v1/account'),
            headers: <String, String>{
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AccountDeletionException('network_unavailable');
    } on SocketException {
      throw const AccountDeletionException('network_unavailable');
    } on http.ClientException {
      throw const AccountDeletionException('network_unavailable');
    }

    Map<String, dynamic> json = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Preserve the HTTP status as the useful failure signal.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountDeletionException(
        json['error']?.toString() ??
            (response.statusCode == 404
                ? 'account_deletion_endpoint_unavailable'
                : 'account_deletion_failed'),
      );
    }
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.code);

  final String code;

  @override
  String toString() => code;
}
