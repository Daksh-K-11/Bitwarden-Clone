import 'package:freezed_annotation/freezed_annotation.dart';

import 'item_type.dart';

part 'vault_models.freezed.dart';
part 'vault_models.g.dart';

/// Custom field types. All custom field *names and values* are encrypted
/// inside the item payload regardless of type.
enum CustomFieldType { text, hidden, boolean, url, email, date, number, multiline }

@freezed
abstract class CustomField with _$CustomField {
  const factory CustomField({
    required String id,
    required String name,
    @Default('') String value,
    @Default(CustomFieldType.text) CustomFieldType type,
  }) = _CustomField;

  const CustomField._();

  /// Hidden fields are never indexed for search and are masked by default.
  bool get isSensitive => type == CustomFieldType.hidden;

  factory CustomField.fromJson(Map<String, dynamic> json) => _$CustomFieldFromJson(json);
}

@freezed
abstract class PasswordHistoryEntry with _$PasswordHistoryEntry {
  const factory PasswordHistoryEntry({
    required String password,
    required DateTime changedAt,
    @Default('password') String fieldKey,
  }) = _PasswordHistoryEntry;

  factory PasswordHistoryEntry.fromJson(Map<String, dynamic> json) => _$PasswordHistoryEntryFromJson(json);
}

/// Attachment metadata. Lives inside the encrypted item payload, so file
/// names, types and sizes are not visible to the server.
@freezed
abstract class AttachmentMeta with _$AttachmentMeta {
  const factory AttachmentMeta({
    required String id,
    required String fileName,
    required String mimeType,
    required int size,
    required DateTime createdAt,

    /// Random per-file key wrapped by the attachment subkey (EncBlob b64).
    required String wrappedFileKey,

    /// SHA-256 of the encrypted blob.
    required String cipherSha256,
    required int encryptedSize,
  }) = _AttachmentMeta;

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) => _$AttachmentMetaFromJson(json);
}

/// A decrypted vault item. Exists only in memory while unlocked.
@freezed
abstract class VaultItem with _$VaultItem {
  const factory VaultItem({
    required String id,
    required ItemType type,
    required String name,

    /// Template field values keyed by [FieldSpec.key].
    @Default(<String, String>{}) Map<String, String> fields,

    /// Website URLs (login items).
    @Default(<String>[]) List<String> uris,

    /// `otpauth://` URI (or bare base32 secret) for TOTP.
    String? totp,
    @Default('') String notes,
    @Default(<CustomField>[]) List<CustomField> customFields,
    @Default(<PasswordHistoryEntry>[]) List<PasswordHistoryEntry> passwordHistory,
    @Default(<AttachmentMeta>[]) List<AttachmentMeta> attachments,
    String? folderId,
    @Default(<String>[]) List<String> tagIds,
    @Default(false) bool favorite,
    @Default(false) bool archived,

    /// Require device re-authentication to reveal or copy secrets.
    @Default(false) bool reprompt,

    /// Set when moved to Trash. Purged after the retention period.
    DateTime? trashedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? passwordUpdatedAt,

    /// Monotonic edit counter (inside the ciphertext). Lets clients detect a
    /// server replaying an older ciphertext as if it were new.
    @Default(1) int seq,
  }) = _VaultItem;

  const VaultItem._();

  bool get isTrashed => trashedAt != null;

  String field(String key) => fields[key] ?? '';

  factory VaultItem.fromJson(Map<String, dynamic> json) => _$VaultItemFromJson(json);
}

@freezed
abstract class Folder with _$Folder {
  const factory Folder({
    required String id,
    required String name,
    String? parentId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Folder;

  factory Folder.fromJson(Map<String, dynamic> json) => _$FolderFromJson(json);
}

@freezed
abstract class Tag with _$Tag {
  const factory Tag({
    required String id,
    required String name,
    @Default(0xFF6366F1) int color,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Tag;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
}
