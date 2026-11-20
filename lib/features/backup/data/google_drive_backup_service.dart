import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

/// Handles automatic backup upload and download to the user's private
/// Google Drive `appDataFolder` using Google Sign-In OAuth tokens.
final class GoogleDriveBackupService {
  static const String _serverClientId =
      '80143681231-qdjv369q92chcon90jkipdi51a2n6icv.apps.googleusercontent.com';
  static const String _driveScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String _backupFileName = 'easyhisab_backup.json';

  static bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Connects the user's Google account and authorizes the Drive `appDataFolder` scope.
  Future<({String email, Map<String, String> headers})> connectAndAuthorize({
    bool interactive = true,
  }) async {
    await _ensureInitialized();
    GoogleSignInAccount? account =
        await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) {
      if (!interactive) {
        throw StateError('No signed-in Google account found.');
      }
      account = await GoogleSignIn.instance.authenticate();
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      [_driveScope],
      promptIfNecessary: interactive,
    );
    if (headers == null || headers.isEmpty) {
      throw StateError('Google Drive permission was not granted.');
    }
    return (email: account.email, headers: headers);
  }

  /// Finds the existing `easyhisab_backup.json` file in `appDataFolder`, if any.
  Future<({String? fileId, DateTime? modifiedTime})> findLatestBackup(
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?spaces=appDataFolder'
      '&q=name%3D%27$_backupFileName%27%20and%20trashed%3Dfalse'
      '&fields=files(id,name,modifiedTime,size)'
      '&orderBy=modifiedTime%20desc',
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Google Drive query failed (${response.statusCode}): $body',
          uri: uri,
        );
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final files = (data['files'] as List<dynamic>?) ?? const [];
      if (files.isEmpty) {
        return (fileId: null, modifiedTime: null);
      }
      final first = files.first as Map<String, dynamic>;
      final modStr = first['modifiedTime'] as String?;
      return (
        fileId: first['id'] as String?,
        modifiedTime: modStr != null ? DateTime.tryParse(modStr) : null,
      );
    } finally {
      client.close();
    }
  }

  /// Uploads (or updates) `easyhisab_backup.json` in Google Drive `appDataFolder`.
  Future<DateTime> uploadBackup({
    required String jsonContent,
    required Map<String, String> headers,
  }) async {
    final existing = await findLatestBackup(headers);
    final client = HttpClient();
    try {
      if (existing.fileId != null) {
        final uri = Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/${existing.fileId}?uploadType=media',
        );
        final request = await client.patchUrl(uri);
        headers.forEach(request.headers.set);
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonContent));
        final response = await request.close();
        final body = await utf8.decodeStream(response);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Google Drive update failed (${response.statusCode}): $body',
            uri: uri,
          );
        }
      } else {
        const boundary = 'easyhisab_drive_multipart_boundary';
        final uri = Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
        );
        final metadata = jsonEncode({
          'name': _backupFileName,
          'parents': ['appDataFolder'],
        });
        final multipartBody = StringBuffer()
          ..write('--$boundary\r\n')
          ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
          ..write('$metadata\r\n')
          ..write('--$boundary\r\n')
          ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
          ..write('$jsonContent\r\n')
          ..write('--$boundary--\r\n');

        final request = await client.postUrl(uri);
        headers.forEach(request.headers.set);
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'multipart/related; boundary=$boundary',
        );
        request.add(utf8.encode(multipartBody.toString()));
        final response = await request.close();
        final body = await utf8.decodeStream(response);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Google Drive upload failed (${response.statusCode}): $body',
            uri: uri,
          );
        }
      }
      return DateTime.now();
    } finally {
      client.close();
    }
  }

  /// Downloads the latest `easyhisab_backup.json` from Google Drive `appDataFolder`.
  Future<String> downloadLatestBackup(Map<String, String> headers) async {
    final existing = await findLatestBackup(headers);
    if (existing.fileId == null) {
      throw StateError('No backup found on Google Drive for this account yet.');
    }
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/${existing.fileId}?alt=media',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      headers.forEach(request.headers.set);
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Google Drive download failed (${response.statusCode}): $body',
          uri: uri,
        );
      }
      return body;
    } finally {
      client.close();
    }
  }
}
