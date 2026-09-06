import 'package:flutter/foundation.dart';
import 'package:yeso_plant/services/leafie_api_client.dart';
import 'package:yeso_plant/services/sha256.dart';

class UploadedMedia {
  const UploadedMedia({required this.id});

  final String id;
}

class MediaApi {
  MediaApi({LeafieApiClient? client}) : _client = client ?? LeafieApiClient();

  final LeafieApiClient _client;

  Future<UploadedMedia> uploadImage({
    required List<int> bytes,
    required String purpose,
  }) async {
    if (bytes.isEmpty) {
      throw const LeafieApiException(
        code: 'EMPTY_IMAGE',
        message: '선택한 사진을 확인할 수 없습니다.',
        statusCode: 400,
      );
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw const LeafieApiException(
        code: 'MEDIA_FILE_TOO_LARGE',
        message: '사진 용량은 10MB 이하여야 합니다.',
        statusCode: 413,
      );
    }
    final contentType = imageContentType(bytes);
    if (contentType == null) {
      throw const LeafieApiException(
        code: 'MEDIA_IMAGE_TYPE_UNSUPPORTED',
        message: 'JPG, PNG, WebP 사진만 사용할 수 있습니다.',
        statusCode: 422,
      );
    }

    final checksum = await compute(sha256Hex, bytes);
    final presign = await _client.post(
      '/media/presign',
      body: {
        'purpose': purpose,
        'content_type': contentType,
        'size_bytes': bytes.length,
        'checksum_sha256': checksum,
      },
    );
    final upload = _MediaUpload.fromJson(presign);
    await _client.putBytes(upload.url, bytes: bytes, headers: upload.headers);
    final completed = await _client.post(
      '/media/${upload.mediaFileId}/complete',
      body: const {},
    );
    if (completed['status'] != 'READY') {
      throw const LeafieApiException(
        code: 'MEDIA_NOT_READY',
        message: '사진 업로드를 완료하지 못했습니다.',
        statusCode: 409,
      );
    }
    return UploadedMedia(id: upload.mediaFileId);
  }
}

class _MediaUpload {
  const _MediaUpload({
    required this.mediaFileId,
    required this.url,
    required this.headers,
  });

  factory _MediaUpload.fromJson(Map<String, dynamic> json) {
    final mediaFileId = json['media_file_id'];
    final uploadUrl = json['upload_url'];
    final uploadMethod = json['upload_method'];
    final rawHeaders = json['upload_headers'];
    final uri = uploadUrl is String ? Uri.tryParse(uploadUrl) : null;
    if (mediaFileId is! String ||
        mediaFileId.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uploadMethod != 'PUT' ||
        rawHeaders is! Map) {
      throw const LeafieApiException(
        code: 'INVALID_RESPONSE',
        message: '사진 업로드 정보를 확인할 수 없습니다.',
        statusCode: 502,
      );
    }
    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const LeafieApiException(
          code: 'INVALID_RESPONSE',
          message: '사진 업로드 정보를 확인할 수 없습니다.',
          statusCode: 502,
        );
      }
      headers[entry.key as String] = entry.value as String;
    }
    return _MediaUpload(
      mediaFileId: mediaFileId,
      url: uri,
      headers: Map.unmodifiable(headers),
    );
  }

  final String mediaFileId;
  final Uri url;
  final Map<String, String> headers;
}

String? imageContentType(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}
