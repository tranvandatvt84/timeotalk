class ChatAttachmentModel {
  const ChatAttachmentModel({
    this.id,
    this.clientAttachmentId,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
  });

  final String? id;
  final String? clientAttachmentId;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  factory ChatAttachmentModel.fromJson(Map<String, Object?> json) {
    return ChatAttachmentModel(
      id: json['id'] as String?,
      clientAttachmentId: json['client_attachment_id'] as String?,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: _asInt(json['size_bytes']),
      width: _asNullableInt(json['width']),
      height: _asNullableInt(json['height']),
      durationMs: _asNullableInt(json['duration_ms']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (id != null) 'id': id,
      if (clientAttachmentId != null)
        'client_attachment_id': clientAttachmentId,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
    };
  }

  ChatAttachmentModel copyWith({
    String? id,
    String? clientAttachmentId,
    String? storagePath,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    int? durationMs,
  }) {
    return ChatAttachmentModel(
      id: id ?? this.id,
      clientAttachmentId: clientAttachmentId ?? this.clientAttachmentId,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.parse(value.toString());
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}
