// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CustomField _$CustomFieldFromJson(Map<String, dynamic> json) => _CustomField(
  id: json['id'] as String,
  name: json['name'] as String,
  value: json['value'] as String? ?? '',
  type: $enumDecodeNullable(_$CustomFieldTypeEnumMap, json['type']) ?? CustomFieldType.text,
);

Map<String, dynamic> _$CustomFieldToJson(_CustomField instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'value': instance.value,
  'type': _$CustomFieldTypeEnumMap[instance.type]!,
};

const _$CustomFieldTypeEnumMap = {
  CustomFieldType.text: 'text',
  CustomFieldType.hidden: 'hidden',
  CustomFieldType.boolean: 'boolean',
  CustomFieldType.url: 'url',
  CustomFieldType.email: 'email',
  CustomFieldType.date: 'date',
  CustomFieldType.number: 'number',
  CustomFieldType.multiline: 'multiline',
};

_PasswordHistoryEntry _$PasswordHistoryEntryFromJson(Map<String, dynamic> json) => _PasswordHistoryEntry(
  password: json['password'] as String,
  changedAt: DateTime.parse(json['changedAt'] as String),
  fieldKey: json['fieldKey'] as String? ?? 'password',
);

Map<String, dynamic> _$PasswordHistoryEntryToJson(_PasswordHistoryEntry instance) => <String, dynamic>{
  'password': instance.password,
  'changedAt': instance.changedAt.toIso8601String(),
  'fieldKey': instance.fieldKey,
};

_AttachmentMeta _$AttachmentMetaFromJson(Map<String, dynamic> json) => _AttachmentMeta(
  id: json['id'] as String,
  fileName: json['fileName'] as String,
  mimeType: json['mimeType'] as String,
  size: (json['size'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  wrappedFileKey: json['wrappedFileKey'] as String,
  cipherSha256: json['cipherSha256'] as String,
  encryptedSize: (json['encryptedSize'] as num).toInt(),
);

Map<String, dynamic> _$AttachmentMetaToJson(_AttachmentMeta instance) => <String, dynamic>{
  'id': instance.id,
  'fileName': instance.fileName,
  'mimeType': instance.mimeType,
  'size': instance.size,
  'createdAt': instance.createdAt.toIso8601String(),
  'wrappedFileKey': instance.wrappedFileKey,
  'cipherSha256': instance.cipherSha256,
  'encryptedSize': instance.encryptedSize,
};

_VaultItem _$VaultItemFromJson(Map<String, dynamic> json) => _VaultItem(
  id: json['id'] as String,
  type: $enumDecode(_$ItemTypeEnumMap, json['type']),
  name: json['name'] as String,
  fields:
      (json['fields'] as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String)) ?? const <String, String>{},
  uris: (json['uris'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  totp: json['totp'] as String?,
  notes: json['notes'] as String? ?? '',
  customFields:
      (json['customFields'] as List<dynamic>?)?.map((e) => CustomField.fromJson(e as Map<String, dynamic>)).toList() ??
      const <CustomField>[],
  passwordHistory:
      (json['passwordHistory'] as List<dynamic>?)
          ?.map((e) => PasswordHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PasswordHistoryEntry>[],
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => AttachmentMeta.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AttachmentMeta>[],
  folderId: json['folderId'] as String?,
  tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  favorite: json['favorite'] as bool? ?? false,
  archived: json['archived'] as bool? ?? false,
  reprompt: json['reprompt'] as bool? ?? false,
  trashedAt: json['trashedAt'] == null ? null : DateTime.parse(json['trashedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  passwordUpdatedAt: json['passwordUpdatedAt'] == null ? null : DateTime.parse(json['passwordUpdatedAt'] as String),
  seq: (json['seq'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$VaultItemToJson(_VaultItem instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$ItemTypeEnumMap[instance.type]!,
  'name': instance.name,
  'fields': instance.fields,
  'uris': instance.uris,
  'totp': instance.totp,
  'notes': instance.notes,
  'customFields': instance.customFields,
  'passwordHistory': instance.passwordHistory,
  'attachments': instance.attachments,
  'folderId': instance.folderId,
  'tagIds': instance.tagIds,
  'favorite': instance.favorite,
  'archived': instance.archived,
  'reprompt': instance.reprompt,
  'trashedAt': instance.trashedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'passwordUpdatedAt': instance.passwordUpdatedAt?.toIso8601String(),
  'seq': instance.seq,
};

const _$ItemTypeEnumMap = {
  ItemType.login: 'login',
  ItemType.secureNote: 'secureNote',
  ItemType.card: 'card',
  ItemType.identity: 'identity',
  ItemType.sshKey: 'sshKey',
  ItemType.apiKey: 'apiKey',
  ItemType.recoveryCodes: 'recoveryCodes',
  ItemType.wifi: 'wifi',
  ItemType.database: 'database',
  ItemType.softwareLicense: 'softwareLicense',
  ItemType.passport: 'passport',
  ItemType.driversLicense: 'driversLicense',
  ItemType.bankAccount: 'bankAccount',
  ItemType.cryptoWallet: 'cryptoWallet',
  ItemType.custom: 'custom',
};

_Folder _$FolderFromJson(Map<String, dynamic> json) => _Folder(
  id: json['id'] as String,
  name: json['name'] as String,
  parentId: json['parentId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$FolderToJson(_Folder instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'parentId': instance.parentId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_Tag _$TagFromJson(Map<String, dynamic> json) => _Tag(
  id: json['id'] as String,
  name: json['name'] as String,
  color: (json['color'] as num?)?.toInt() ?? 0xFF6366F1,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$TagToJson(_Tag instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'color': instance.color,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
