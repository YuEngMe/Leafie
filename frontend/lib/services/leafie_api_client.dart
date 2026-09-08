import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AccessTokenProvider = Future<String?> Function();
typedef LeafieTransport =
    Future<LeafieHttpResponse> Function(LeafieHttpRequest request);

class LeafieHttpRequest {
  const LeafieHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
    this.rawBody,
  }) : assert(body == null || rawBody == null);

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, Object?>? body;
  final List<int>? rawBody;
}

class LeafieHttpResponse {
  const LeafieHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class LeafieApiException implements Exception {
  const LeafieApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => '$code ($statusCode): $message';
}

class LeafieApiClient {
  LeafieApiClient({
    String? baseUrl,
    AccessTokenProvider? accessTokenProvider,
    LeafieTransport? transport,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(baseUrl ?? _configuredBaseUrl()),
       _accessTokenProvider = accessTokenProvider ?? _supabaseAccessToken,
       _transport = transport ?? _sendWithHttpClient,
       _requestTimeout = requestTimeout;

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final LeafieTransport _transport;
  final Duration _requestTimeout;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) => _request('GET', path, queryParameters: queryParameters);

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, Object?> body,
  }) => _request('POST', path, body: body);

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, Object?> body,
  }) => _request('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, Object?> body,
  }) => _request('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, Object?>? body,
  }) => _request('DELETE', path, body: body);

  /// Sends bytes to a storage-provider presigned URL.
  ///
  /// The URL itself authorizes the upload, so the app's bearer token must not
  /// be attached to this request.
  Future<void> putBytes(
    Uri uploadUri, {
    required List<int> bytes,
    required Map<String, String> headers,
  }) async {
    try {
      final response = await _transport(
        LeafieHttpRequest(
          method: 'PUT',
          uri: uploadUri,
          headers: headers,
          rawBody: bytes,
        ),
      ).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LeafieApiException(
          code: 'MEDIA_UPLOAD_FAILED',
          message: '사진을 업로드하지 못했습니다.',
          statusCode: response.statusCode,
        );
      }
    } on LeafieApiException {
      rethrow;
    } on IOException {
      throw const LeafieApiException(
        code: 'NETWORK_ERROR',
        message: '서버에 연결할 수 없습니다.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw const LeafieApiException(
        code: 'NETWORK_TIMEOUT',
        message: '사진 업로드가 늦어지고 있어요. 다시 시도해 주세요.',
        statusCode: 0,
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final token = (await _accessTokenProvider())?.trim();
    if (token == null || token.isEmpty) {
      throw const LeafieApiException(
        code: 'AUTH_REQUIRED',
        message: '로그인이 필요합니다.',
        statusCode: 401,
      );
    }

    try {
      final response = await _transport(
        LeafieHttpRequest(
          method: method,
          uri: _resolve(path, queryParameters),
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.authorizationHeader: 'Bearer $token',
            if (body != null)
              HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
          },
          body: body,
        ),
      ).timeout(_requestTimeout);
      final responseText = response.body;
      final decoded = responseText.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) {
        throw const LeafieApiException(
          code: 'INVALID_RESPONSE',
          message: '서버 응답 형식을 확인할 수 없습니다.',
          statusCode: 502,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded['error'];
        throw LeafieApiException(
          code: error is Map
              ? error['code']?.toString() ?? 'API_ERROR'
              : 'API_ERROR',
          message: error is Map
              ? error['message']?.toString() ?? '요청을 처리하지 못했습니다.'
              : '요청을 처리하지 못했습니다.',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on LeafieApiException {
      rethrow;
    } on IOException {
      throw const LeafieApiException(
        code: 'NETWORK_ERROR',
        message: '서버에 연결할 수 없습니다.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw const LeafieApiException(
        code: 'NETWORK_TIMEOUT',
        message: '서버 응답이 늦어지고 있어요. 다시 시도해 주세요.',
        statusCode: 0,
      );
    } on FormatException {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '서버 응답 형식을 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
  }

  Uri _resolve(String path, Map<String, String>? queryParameters) {
    final childSegments = path
        .split('/')
        .where((segment) => segment.isNotEmpty);
    return _baseUri.replace(
      pathSegments: [
        ..._baseUri.pathSegments.where((segment) => segment.isNotEmpty),
        ...childSegments,
      ],
      queryParameters: queryParameters,
    );
  }
}

Future<LeafieHttpResponse> _sendWithHttpClient(LeafieHttpRequest input) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.openUrl(input.method, input.uri);
    input.headers.forEach(request.headers.set);
    if (input.body != null) request.add(encodeLeafieJsonBody(input.body!));
    if (input.rawBody != null) request.add(input.rawBody!);
    final response = await request.close();
    return LeafieHttpResponse(
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

@visibleForTesting
List<int> encodeLeafieJsonBody(Map<String, Object?> body) =>
    utf8.encode(jsonEncode(body));

String _configuredBaseUrl() {
  try {
    final configured = dotenv.env['API_BASE_URL']?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
  } catch (_) {
    // Widget tests do not load dotenv. Keep the local simulator default there.
  }
  if (kDebugMode) return 'http://localhost:8000/api/v1';
  throw StateError('API_BASE_URL must be set for non-debug builds.');
}

/// 만료된 토큰을 그대로 보내면 서버가 401을 주고, main.dart는 그 실패를
/// 로그인 실패로 보지 않고 홈으로 보내 닉네임 화면을 건너뛴다. 앱을 오래
/// 뒀다 켠 콜드스타트에서 실제로 났던 문제라, 요청 전에 표부터 갈아 둔다.
Future<String?> _supabaseAccessToken() async {
  try {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return null;
    if (sessionExpiresSoon(session)) {
      try {
        final refreshed = (await auth.refreshSession()).session;
        if (refreshed != null) return refreshed.accessToken;
      } catch (_) {
        // 갱신 실패(오프라인, 폐기된 refresh token)는 기존 토큰으로 보내고
        // 서버의 401 처리에 맡긴다.
      }
    }
    return session.accessToken;
  } catch (_) {
    return null;
  }
}

/// 만료 30초 전부터 새 토큰으로 본다. 요청이 서버에 닿기 전에 끊기는 틈을 막는다.
@visibleForTesting
bool sessionExpiresSoon(Session session, {DateTime? now}) {
  final expiresAt = session.expiresAt;
  if (expiresAt == null) return false;
  final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  return expiry.difference(now ?? DateTime.now()) <=
      const Duration(seconds: 30);
}
