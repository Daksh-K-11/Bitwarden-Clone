// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vault_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomField {

 String get id; String get name; String get value; CustomFieldType get type;
/// Create a copy of CustomField
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomFieldCopyWith<CustomField> get copyWith => _$CustomFieldCopyWithImpl<CustomField>(this as CustomField, _$identity);

  /// Serializes this CustomField to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CustomField;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomField&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.type, _this.type) || other.type == _this.type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CustomField;
  return Object.hash(runtimeType,_this.id,_this.name,_this.value,_this.type);
}

@override
String toString() {
  final _this = this as CustomField;
  return 'CustomField(id: ${_this.id}, name: ${_this.name}, value: ${_this.value}, type: ${_this.type})';
}


}

/// @nodoc
abstract mixin class $CustomFieldCopyWith<$Res>  {
  factory $CustomFieldCopyWith(CustomField value, $Res Function(CustomField) _then) = _$CustomFieldCopyWithImpl;
@useResult
$Res call({
 String id, String name, String value, CustomFieldType type
});




}
/// @nodoc
class _$CustomFieldCopyWithImpl<$Res>
    implements $CustomFieldCopyWith<$Res> {
  _$CustomFieldCopyWithImpl(this._self, this._then);

  final CustomField _self;
  final $Res Function(CustomField) _then;

/// Create a copy of CustomField
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? value = null,Object? type = null,}) {
  return _then(CustomField(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CustomFieldType,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomField].
extension CustomFieldPatterns on CustomField {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomField value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomField() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomField value)  $default,){
final _that = this;
switch (_that) {
case _CustomField():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomField value)?  $default,){
final _that = this;
switch (_that) {
case _CustomField() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String value,  CustomFieldType type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomField() when $default != null:
return $default(_that.id,_that.name,_that.value,_that.type);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String value,  CustomFieldType type)  $default,) {final _that = this;
switch (_that) {
case _CustomField():
return $default(_that.id,_that.name,_that.value,_that.type);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String value,  CustomFieldType type)?  $default,) {final _that = this;
switch (_that) {
case _CustomField() when $default != null:
return $default(_that.id,_that.name,_that.value,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomField extends CustomField {
  const _CustomField({required this.id, required this.name, this.value = '', this.type = CustomFieldType.text}): super._();
  factory _CustomField.fromJson(Map<String, dynamic> json) => _$CustomFieldFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String value;
@override@JsonKey() final  CustomFieldType type;

/// Create a copy of CustomField
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomFieldCopyWith<_CustomField> get copyWith => __$CustomFieldCopyWithImpl<_CustomField>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomFieldToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomField&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,value,type);
}

@override
String toString() {
    return 'CustomField(id: $id, name: $name, value: $value, type: $type)';
}


}

/// @nodoc
abstract mixin class _$CustomFieldCopyWith<$Res> implements $CustomFieldCopyWith<$Res> {
  factory _$CustomFieldCopyWith(_CustomField value, $Res Function(_CustomField) _then) = __$CustomFieldCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String value, CustomFieldType type
});




}
/// @nodoc
class __$CustomFieldCopyWithImpl<$Res>
    implements _$CustomFieldCopyWith<$Res> {
  __$CustomFieldCopyWithImpl(this._self, this._then);

  final _CustomField _self;
  final $Res Function(_CustomField) _then;

/// Create a copy of CustomField
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? value = null,Object? type = null,}) {
  return _then(_CustomField(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CustomFieldType,
  ));
}


}


/// @nodoc
mixin _$PasswordHistoryEntry {

 String get password; DateTime get changedAt; String get fieldKey;
/// Create a copy of PasswordHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PasswordHistoryEntryCopyWith<PasswordHistoryEntry> get copyWith => _$PasswordHistoryEntryCopyWithImpl<PasswordHistoryEntry>(this as PasswordHistoryEntry, _$identity);

  /// Serializes this PasswordHistoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PasswordHistoryEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PasswordHistoryEntry&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.changedAt, _this.changedAt) || other.changedAt == _this.changedAt)&&(identical(other.fieldKey, _this.fieldKey) || other.fieldKey == _this.fieldKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PasswordHistoryEntry;
  return Object.hash(runtimeType,_this.password,_this.changedAt,_this.fieldKey);
}

@override
String toString() {
  final _this = this as PasswordHistoryEntry;
  return 'PasswordHistoryEntry(password: ${_this.password}, changedAt: ${_this.changedAt}, fieldKey: ${_this.fieldKey})';
}


}

/// @nodoc
abstract mixin class $PasswordHistoryEntryCopyWith<$Res>  {
  factory $PasswordHistoryEntryCopyWith(PasswordHistoryEntry value, $Res Function(PasswordHistoryEntry) _then) = _$PasswordHistoryEntryCopyWithImpl;
@useResult
$Res call({
 String password, DateTime changedAt, String fieldKey
});




}
/// @nodoc
class _$PasswordHistoryEntryCopyWithImpl<$Res>
    implements $PasswordHistoryEntryCopyWith<$Res> {
  _$PasswordHistoryEntryCopyWithImpl(this._self, this._then);

  final PasswordHistoryEntry _self;
  final $Res Function(PasswordHistoryEntry) _then;

/// Create a copy of PasswordHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? password = null,Object? changedAt = null,Object? fieldKey = null,}) {
  return _then(PasswordHistoryEntry(
password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,changedAt: null == changedAt ? _self.changedAt : changedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fieldKey: null == fieldKey ? _self.fieldKey : fieldKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PasswordHistoryEntry].
extension PasswordHistoryEntryPatterns on PasswordHistoryEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PasswordHistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PasswordHistoryEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PasswordHistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _PasswordHistoryEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PasswordHistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _PasswordHistoryEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String password,  DateTime changedAt,  String fieldKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PasswordHistoryEntry() when $default != null:
return $default(_that.password,_that.changedAt,_that.fieldKey);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String password,  DateTime changedAt,  String fieldKey)  $default,) {final _that = this;
switch (_that) {
case _PasswordHistoryEntry():
return $default(_that.password,_that.changedAt,_that.fieldKey);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String password,  DateTime changedAt,  String fieldKey)?  $default,) {final _that = this;
switch (_that) {
case _PasswordHistoryEntry() when $default != null:
return $default(_that.password,_that.changedAt,_that.fieldKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PasswordHistoryEntry implements PasswordHistoryEntry {
  const _PasswordHistoryEntry({required this.password, required this.changedAt, this.fieldKey = 'password'});
  factory _PasswordHistoryEntry.fromJson(Map<String, dynamic> json) => _$PasswordHistoryEntryFromJson(json);

@override final  String password;
@override final  DateTime changedAt;
@override@JsonKey() final  String fieldKey;

/// Create a copy of PasswordHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PasswordHistoryEntryCopyWith<_PasswordHistoryEntry> get copyWith => __$PasswordHistoryEntryCopyWithImpl<_PasswordHistoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PasswordHistoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PasswordHistoryEntry&&(identical(other.password, password) || other.password == password)&&(identical(other.changedAt, changedAt) || other.changedAt == changedAt)&&(identical(other.fieldKey, fieldKey) || other.fieldKey == fieldKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,password,changedAt,fieldKey);
}

@override
String toString() {
    return 'PasswordHistoryEntry(password: $password, changedAt: $changedAt, fieldKey: $fieldKey)';
}


}

/// @nodoc
abstract mixin class _$PasswordHistoryEntryCopyWith<$Res> implements $PasswordHistoryEntryCopyWith<$Res> {
  factory _$PasswordHistoryEntryCopyWith(_PasswordHistoryEntry value, $Res Function(_PasswordHistoryEntry) _then) = __$PasswordHistoryEntryCopyWithImpl;
@override @useResult
$Res call({
 String password, DateTime changedAt, String fieldKey
});




}
/// @nodoc
class __$PasswordHistoryEntryCopyWithImpl<$Res>
    implements _$PasswordHistoryEntryCopyWith<$Res> {
  __$PasswordHistoryEntryCopyWithImpl(this._self, this._then);

  final _PasswordHistoryEntry _self;
  final $Res Function(_PasswordHistoryEntry) _then;

/// Create a copy of PasswordHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? password = null,Object? changedAt = null,Object? fieldKey = null,}) {
  return _then(_PasswordHistoryEntry(
password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,changedAt: null == changedAt ? _self.changedAt : changedAt // ignore: cast_nullable_to_non_nullable
as DateTime,fieldKey: null == fieldKey ? _self.fieldKey : fieldKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AttachmentMeta {

 String get id; String get fileName; String get mimeType; int get size; DateTime get createdAt;/// Random per-file key wrapped by the attachment subkey (EncBlob b64).
 String get wrappedFileKey;/// SHA-256 of the encrypted blob.
 String get cipherSha256; int get encryptedSize;
/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentMetaCopyWith<AttachmentMeta> get copyWith => _$AttachmentMetaCopyWithImpl<AttachmentMeta>(this as AttachmentMeta, _$identity);

  /// Serializes this AttachmentMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AttachmentMeta;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttachmentMeta&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.size, _this.size) || other.size == _this.size)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.wrappedFileKey, _this.wrappedFileKey) || other.wrappedFileKey == _this.wrappedFileKey)&&(identical(other.cipherSha256, _this.cipherSha256) || other.cipherSha256 == _this.cipherSha256)&&(identical(other.encryptedSize, _this.encryptedSize) || other.encryptedSize == _this.encryptedSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AttachmentMeta;
  return Object.hash(runtimeType,_this.id,_this.fileName,_this.mimeType,_this.size,_this.createdAt,_this.wrappedFileKey,_this.cipherSha256,_this.encryptedSize);
}

@override
String toString() {
  final _this = this as AttachmentMeta;
  return 'AttachmentMeta(id: ${_this.id}, fileName: ${_this.fileName}, mimeType: ${_this.mimeType}, size: ${_this.size}, createdAt: ${_this.createdAt}, wrappedFileKey: ${_this.wrappedFileKey}, cipherSha256: ${_this.cipherSha256}, encryptedSize: ${_this.encryptedSize})';
}


}

/// @nodoc
abstract mixin class $AttachmentMetaCopyWith<$Res>  {
  factory $AttachmentMetaCopyWith(AttachmentMeta value, $Res Function(AttachmentMeta) _then) = _$AttachmentMetaCopyWithImpl;
@useResult
$Res call({
 String id, String fileName, String mimeType, int size, DateTime createdAt, String wrappedFileKey, String cipherSha256, int encryptedSize
});




}
/// @nodoc
class _$AttachmentMetaCopyWithImpl<$Res>
    implements $AttachmentMetaCopyWith<$Res> {
  _$AttachmentMetaCopyWithImpl(this._self, this._then);

  final AttachmentMeta _self;
  final $Res Function(AttachmentMeta) _then;

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fileName = null,Object? mimeType = null,Object? size = null,Object? createdAt = null,Object? wrappedFileKey = null,Object? cipherSha256 = null,Object? encryptedSize = null,}) {
  return _then(AttachmentMeta(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,wrappedFileKey: null == wrappedFileKey ? _self.wrappedFileKey : wrappedFileKey // ignore: cast_nullable_to_non_nullable
as String,cipherSha256: null == cipherSha256 ? _self.cipherSha256 : cipherSha256 // ignore: cast_nullable_to_non_nullable
as String,encryptedSize: null == encryptedSize ? _self.encryptedSize : encryptedSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AttachmentMeta].
extension AttachmentMetaPatterns on AttachmentMeta {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttachmentMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttachmentMeta value)  $default,){
final _that = this;
switch (_that) {
case _AttachmentMeta():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttachmentMeta value)?  $default,){
final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fileName,  String mimeType,  int size,  DateTime createdAt,  String wrappedFileKey,  String cipherSha256,  int encryptedSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
return $default(_that.id,_that.fileName,_that.mimeType,_that.size,_that.createdAt,_that.wrappedFileKey,_that.cipherSha256,_that.encryptedSize);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fileName,  String mimeType,  int size,  DateTime createdAt,  String wrappedFileKey,  String cipherSha256,  int encryptedSize)  $default,) {final _that = this;
switch (_that) {
case _AttachmentMeta():
return $default(_that.id,_that.fileName,_that.mimeType,_that.size,_that.createdAt,_that.wrappedFileKey,_that.cipherSha256,_that.encryptedSize);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fileName,  String mimeType,  int size,  DateTime createdAt,  String wrappedFileKey,  String cipherSha256,  int encryptedSize)?  $default,) {final _that = this;
switch (_that) {
case _AttachmentMeta() when $default != null:
return $default(_that.id,_that.fileName,_that.mimeType,_that.size,_that.createdAt,_that.wrappedFileKey,_that.cipherSha256,_that.encryptedSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttachmentMeta implements AttachmentMeta {
  const _AttachmentMeta({required this.id, required this.fileName, required this.mimeType, required this.size, required this.createdAt, required this.wrappedFileKey, required this.cipherSha256, required this.encryptedSize});
  factory _AttachmentMeta.fromJson(Map<String, dynamic> json) => _$AttachmentMetaFromJson(json);

@override final  String id;
@override final  String fileName;
@override final  String mimeType;
@override final  int size;
@override final  DateTime createdAt;
/// Random per-file key wrapped by the attachment subkey (EncBlob b64).
@override final  String wrappedFileKey;
/// SHA-256 of the encrypted blob.
@override final  String cipherSha256;
@override final  int encryptedSize;

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentMetaCopyWith<_AttachmentMeta> get copyWith => __$AttachmentMetaCopyWithImpl<_AttachmentMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttachmentMetaToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttachmentMeta&&(identical(other.id, id) || other.id == id)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.size, size) || other.size == size)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.wrappedFileKey, wrappedFileKey) || other.wrappedFileKey == wrappedFileKey)&&(identical(other.cipherSha256, cipherSha256) || other.cipherSha256 == cipherSha256)&&(identical(other.encryptedSize, encryptedSize) || other.encryptedSize == encryptedSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,fileName,mimeType,size,createdAt,wrappedFileKey,cipherSha256,encryptedSize);
}

@override
String toString() {
    return 'AttachmentMeta(id: $id, fileName: $fileName, mimeType: $mimeType, size: $size, createdAt: $createdAt, wrappedFileKey: $wrappedFileKey, cipherSha256: $cipherSha256, encryptedSize: $encryptedSize)';
}


}

/// @nodoc
abstract mixin class _$AttachmentMetaCopyWith<$Res> implements $AttachmentMetaCopyWith<$Res> {
  factory _$AttachmentMetaCopyWith(_AttachmentMeta value, $Res Function(_AttachmentMeta) _then) = __$AttachmentMetaCopyWithImpl;
@override @useResult
$Res call({
 String id, String fileName, String mimeType, int size, DateTime createdAt, String wrappedFileKey, String cipherSha256, int encryptedSize
});




}
/// @nodoc
class __$AttachmentMetaCopyWithImpl<$Res>
    implements _$AttachmentMetaCopyWith<$Res> {
  __$AttachmentMetaCopyWithImpl(this._self, this._then);

  final _AttachmentMeta _self;
  final $Res Function(_AttachmentMeta) _then;

/// Create a copy of AttachmentMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fileName = null,Object? mimeType = null,Object? size = null,Object? createdAt = null,Object? wrappedFileKey = null,Object? cipherSha256 = null,Object? encryptedSize = null,}) {
  return _then(_AttachmentMeta(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,wrappedFileKey: null == wrappedFileKey ? _self.wrappedFileKey : wrappedFileKey // ignore: cast_nullable_to_non_nullable
as String,cipherSha256: null == cipherSha256 ? _self.cipherSha256 : cipherSha256 // ignore: cast_nullable_to_non_nullable
as String,encryptedSize: null == encryptedSize ? _self.encryptedSize : encryptedSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$VaultItem {

 String get id; ItemType get type; String get name;/// Template field values keyed by [FieldSpec.key].
 Map<String, String> get fields;/// Website URLs (login items).
 List<String> get uris;/// `otpauth://` URI (or bare base32 secret) for TOTP.
 String? get totp; String get notes; List<CustomField> get customFields; List<PasswordHistoryEntry> get passwordHistory; List<AttachmentMeta> get attachments; String? get folderId; List<String> get tagIds; bool get favorite; bool get archived;/// Require device re-authentication to reveal or copy secrets.
 bool get reprompt;/// Set when moved to Trash. Purged after the retention period.
 DateTime? get trashedAt; DateTime get createdAt; DateTime get updatedAt; DateTime? get passwordUpdatedAt;/// Monotonic edit counter (inside the ciphertext). Lets clients detect a
/// server replaying an older ciphertext as if it were new.
 int get seq;
/// Create a copy of VaultItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VaultItemCopyWith<VaultItem> get copyWith => _$VaultItemCopyWithImpl<VaultItem>(this as VaultItem, _$identity);

  /// Serializes this VaultItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VaultItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VaultItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.fields, _this.fields)&&const DeepCollectionEquality().equals(other.uris, _this.uris)&&(identical(other.totp, _this.totp) || other.totp == _this.totp)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&const DeepCollectionEquality().equals(other.customFields, _this.customFields)&&const DeepCollectionEquality().equals(other.passwordHistory, _this.passwordHistory)&&const DeepCollectionEquality().equals(other.attachments, _this.attachments)&&(identical(other.folderId, _this.folderId) || other.folderId == _this.folderId)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&(identical(other.favorite, _this.favorite) || other.favorite == _this.favorite)&&(identical(other.archived, _this.archived) || other.archived == _this.archived)&&(identical(other.reprompt, _this.reprompt) || other.reprompt == _this.reprompt)&&(identical(other.trashedAt, _this.trashedAt) || other.trashedAt == _this.trashedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.passwordUpdatedAt, _this.passwordUpdatedAt) || other.passwordUpdatedAt == _this.passwordUpdatedAt)&&(identical(other.seq, _this.seq) || other.seq == _this.seq));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VaultItem;
  return Object.hashAll([runtimeType,_this.id,_this.type,_this.name,const DeepCollectionEquality().hash(_this.fields),const DeepCollectionEquality().hash(_this.uris),_this.totp,_this.notes,const DeepCollectionEquality().hash(_this.customFields),const DeepCollectionEquality().hash(_this.passwordHistory),const DeepCollectionEquality().hash(_this.attachments),_this.folderId,const DeepCollectionEquality().hash(_this.tagIds),_this.favorite,_this.archived,_this.reprompt,_this.trashedAt,_this.createdAt,_this.updatedAt,_this.passwordUpdatedAt,_this.seq]);
}

@override
String toString() {
  final _this = this as VaultItem;
  return 'VaultItem(id: ${_this.id}, type: ${_this.type}, name: ${_this.name}, fields: ${_this.fields}, uris: ${_this.uris}, totp: ${_this.totp}, notes: ${_this.notes}, customFields: ${_this.customFields}, passwordHistory: ${_this.passwordHistory}, attachments: ${_this.attachments}, folderId: ${_this.folderId}, tagIds: ${_this.tagIds}, favorite: ${_this.favorite}, archived: ${_this.archived}, reprompt: ${_this.reprompt}, trashedAt: ${_this.trashedAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, passwordUpdatedAt: ${_this.passwordUpdatedAt}, seq: ${_this.seq})';
}


}

/// @nodoc
abstract mixin class $VaultItemCopyWith<$Res>  {
  factory $VaultItemCopyWith(VaultItem value, $Res Function(VaultItem) _then) = _$VaultItemCopyWithImpl;
@useResult
$Res call({
 String id, ItemType type, String name, Map<String, String> fields, List<String> uris, String? totp, String notes, List<CustomField> customFields, List<PasswordHistoryEntry> passwordHistory, List<AttachmentMeta> attachments, String? folderId, List<String> tagIds, bool favorite, bool archived, bool reprompt, DateTime? trashedAt, DateTime createdAt, DateTime updatedAt, DateTime? passwordUpdatedAt, int seq
});




}
/// @nodoc
class _$VaultItemCopyWithImpl<$Res>
    implements $VaultItemCopyWith<$Res> {
  _$VaultItemCopyWithImpl(this._self, this._then);

  final VaultItem _self;
  final $Res Function(VaultItem) _then;

/// Create a copy of VaultItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? name = null,Object? fields = null,Object? uris = null,Object? totp = freezed,Object? notes = null,Object? customFields = null,Object? passwordHistory = null,Object? attachments = null,Object? folderId = freezed,Object? tagIds = null,Object? favorite = null,Object? archived = null,Object? reprompt = null,Object? trashedAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? passwordUpdatedAt = freezed,Object? seq = null,}) {
  return _then(VaultItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ItemType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,uris: null == uris ? _self.uris : uris // ignore: cast_nullable_to_non_nullable
as List<String>,totp: freezed == totp ? _self.totp : totp // ignore: cast_nullable_to_non_nullable
as String?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,customFields: null == customFields ? _self.customFields : customFields // ignore: cast_nullable_to_non_nullable
as List<CustomField>,passwordHistory: null == passwordHistory ? _self.passwordHistory : passwordHistory // ignore: cast_nullable_to_non_nullable
as List<PasswordHistoryEntry>,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentMeta>,folderId: freezed == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as String?,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,favorite: null == favorite ? _self.favorite : favorite // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,reprompt: null == reprompt ? _self.reprompt : reprompt // ignore: cast_nullable_to_non_nullable
as bool,trashedAt: freezed == trashedAt ? _self.trashedAt : trashedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,passwordUpdatedAt: freezed == passwordUpdatedAt ? _self.passwordUpdatedAt : passwordUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VaultItem].
extension VaultItemPatterns on VaultItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VaultItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VaultItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VaultItem value)  $default,){
final _that = this;
switch (_that) {
case _VaultItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VaultItem value)?  $default,){
final _that = this;
switch (_that) {
case _VaultItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  ItemType type,  String name,  Map<String, String> fields,  List<String> uris,  String? totp,  String notes,  List<CustomField> customFields,  List<PasswordHistoryEntry> passwordHistory,  List<AttachmentMeta> attachments,  String? folderId,  List<String> tagIds,  bool favorite,  bool archived,  bool reprompt,  DateTime? trashedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? passwordUpdatedAt,  int seq)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VaultItem() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.fields,_that.uris,_that.totp,_that.notes,_that.customFields,_that.passwordHistory,_that.attachments,_that.folderId,_that.tagIds,_that.favorite,_that.archived,_that.reprompt,_that.trashedAt,_that.createdAt,_that.updatedAt,_that.passwordUpdatedAt,_that.seq);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  ItemType type,  String name,  Map<String, String> fields,  List<String> uris,  String? totp,  String notes,  List<CustomField> customFields,  List<PasswordHistoryEntry> passwordHistory,  List<AttachmentMeta> attachments,  String? folderId,  List<String> tagIds,  bool favorite,  bool archived,  bool reprompt,  DateTime? trashedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? passwordUpdatedAt,  int seq)  $default,) {final _that = this;
switch (_that) {
case _VaultItem():
return $default(_that.id,_that.type,_that.name,_that.fields,_that.uris,_that.totp,_that.notes,_that.customFields,_that.passwordHistory,_that.attachments,_that.folderId,_that.tagIds,_that.favorite,_that.archived,_that.reprompt,_that.trashedAt,_that.createdAt,_that.updatedAt,_that.passwordUpdatedAt,_that.seq);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  ItemType type,  String name,  Map<String, String> fields,  List<String> uris,  String? totp,  String notes,  List<CustomField> customFields,  List<PasswordHistoryEntry> passwordHistory,  List<AttachmentMeta> attachments,  String? folderId,  List<String> tagIds,  bool favorite,  bool archived,  bool reprompt,  DateTime? trashedAt,  DateTime createdAt,  DateTime updatedAt,  DateTime? passwordUpdatedAt,  int seq)?  $default,) {final _that = this;
switch (_that) {
case _VaultItem() when $default != null:
return $default(_that.id,_that.type,_that.name,_that.fields,_that.uris,_that.totp,_that.notes,_that.customFields,_that.passwordHistory,_that.attachments,_that.folderId,_that.tagIds,_that.favorite,_that.archived,_that.reprompt,_that.trashedAt,_that.createdAt,_that.updatedAt,_that.passwordUpdatedAt,_that.seq);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VaultItem extends VaultItem {
  const _VaultItem({required this.id, required this.type, required this.name,  Map<String, String> fields = const <String, String>{},  List<String> uris = const <String>[], this.totp, this.notes = '',  List<CustomField> customFields = const <CustomField>[],  List<PasswordHistoryEntry> passwordHistory = const <PasswordHistoryEntry>[],  List<AttachmentMeta> attachments = const <AttachmentMeta>[], this.folderId,  List<String> tagIds = const <String>[], this.favorite = false, this.archived = false, this.reprompt = false, this.trashedAt, required this.createdAt, required this.updatedAt, this.passwordUpdatedAt, this.seq = 1}): _fields = fields,_uris = uris,_customFields = customFields,_passwordHistory = passwordHistory,_attachments = attachments,_tagIds = tagIds,super._();
  factory _VaultItem.fromJson(Map<String, dynamic> json) => _$VaultItemFromJson(json);

@override final  String id;
@override final  ItemType type;
@override final  String name;
/// Template field values keyed by [FieldSpec.key].
 final  Map<String, String> _fields;
/// Template field values keyed by [FieldSpec.key].
@override@JsonKey() Map<String, String> get fields {
  if (_fields is EqualUnmodifiableMapView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fields);
}

/// Website URLs (login items).
 final  List<String> _uris;
/// Website URLs (login items).
@override@JsonKey() List<String> get uris {
  if (_uris is EqualUnmodifiableListView) return _uris;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_uris);
}

/// `otpauth://` URI (or bare base32 secret) for TOTP.
@override final  String? totp;
@override@JsonKey() final  String notes;
 final  List<CustomField> _customFields;
@override@JsonKey() List<CustomField> get customFields {
  if (_customFields is EqualUnmodifiableListView) return _customFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_customFields);
}

 final  List<PasswordHistoryEntry> _passwordHistory;
@override@JsonKey() List<PasswordHistoryEntry> get passwordHistory {
  if (_passwordHistory is EqualUnmodifiableListView) return _passwordHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_passwordHistory);
}

 final  List<AttachmentMeta> _attachments;
@override@JsonKey() List<AttachmentMeta> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override final  String? folderId;
 final  List<String> _tagIds;
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

@override@JsonKey() final  bool favorite;
@override@JsonKey() final  bool archived;
/// Require device re-authentication to reveal or copy secrets.
@override@JsonKey() final  bool reprompt;
/// Set when moved to Trash. Purged after the retention period.
@override final  DateTime? trashedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? passwordUpdatedAt;
/// Monotonic edit counter (inside the ciphertext). Lets clients detect a
/// server replaying an older ciphertext as if it were new.
@override@JsonKey() final  int seq;

/// Create a copy of VaultItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VaultItemCopyWith<_VaultItem> get copyWith => __$VaultItemCopyWithImpl<_VaultItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VaultItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VaultItem&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.fields, _fields)&&const DeepCollectionEquality().equals(other.uris, _uris)&&(identical(other.totp, totp) || other.totp == totp)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.customFields, _customFields)&&const DeepCollectionEquality().equals(other.passwordHistory, _passwordHistory)&&const DeepCollectionEquality().equals(other.attachments, _attachments)&&(identical(other.folderId, folderId) || other.folderId == folderId)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&(identical(other.favorite, favorite) || other.favorite == favorite)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.reprompt, reprompt) || other.reprompt == reprompt)&&(identical(other.trashedAt, trashedAt) || other.trashedAt == trashedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.passwordUpdatedAt, passwordUpdatedAt) || other.passwordUpdatedAt == passwordUpdatedAt)&&(identical(other.seq, seq) || other.seq == seq));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,type,name,const DeepCollectionEquality().hash(_fields),const DeepCollectionEquality().hash(_uris),totp,notes,const DeepCollectionEquality().hash(_customFields),const DeepCollectionEquality().hash(_passwordHistory),const DeepCollectionEquality().hash(_attachments),folderId,const DeepCollectionEquality().hash(_tagIds),favorite,archived,reprompt,trashedAt,createdAt,updatedAt,passwordUpdatedAt,seq]);
}

@override
String toString() {
    return 'VaultItem(id: $id, type: $type, name: $name, fields: $fields, uris: $uris, totp: $totp, notes: $notes, customFields: $customFields, passwordHistory: $passwordHistory, attachments: $attachments, folderId: $folderId, tagIds: $tagIds, favorite: $favorite, archived: $archived, reprompt: $reprompt, trashedAt: $trashedAt, createdAt: $createdAt, updatedAt: $updatedAt, passwordUpdatedAt: $passwordUpdatedAt, seq: $seq)';
}


}

/// @nodoc
abstract mixin class _$VaultItemCopyWith<$Res> implements $VaultItemCopyWith<$Res> {
  factory _$VaultItemCopyWith(_VaultItem value, $Res Function(_VaultItem) _then) = __$VaultItemCopyWithImpl;
@override @useResult
$Res call({
 String id, ItemType type, String name, Map<String, String> fields, List<String> uris, String? totp, String notes, List<CustomField> customFields, List<PasswordHistoryEntry> passwordHistory, List<AttachmentMeta> attachments, String? folderId, List<String> tagIds, bool favorite, bool archived, bool reprompt, DateTime? trashedAt, DateTime createdAt, DateTime updatedAt, DateTime? passwordUpdatedAt, int seq
});




}
/// @nodoc
class __$VaultItemCopyWithImpl<$Res>
    implements _$VaultItemCopyWith<$Res> {
  __$VaultItemCopyWithImpl(this._self, this._then);

  final _VaultItem _self;
  final $Res Function(_VaultItem) _then;

/// Create a copy of VaultItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? name = null,Object? fields = null,Object? uris = null,Object? totp = freezed,Object? notes = null,Object? customFields = null,Object? passwordHistory = null,Object? attachments = null,Object? folderId = freezed,Object? tagIds = null,Object? favorite = null,Object? archived = null,Object? reprompt = null,Object? trashedAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? passwordUpdatedAt = freezed,Object? seq = null,}) {
  return _then(_VaultItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ItemType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,uris: null == uris ? _self._uris : uris // ignore: cast_nullable_to_non_nullable
as List<String>,totp: freezed == totp ? _self.totp : totp // ignore: cast_nullable_to_non_nullable
as String?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,customFields: null == customFields ? _self._customFields : customFields // ignore: cast_nullable_to_non_nullable
as List<CustomField>,passwordHistory: null == passwordHistory ? _self._passwordHistory : passwordHistory // ignore: cast_nullable_to_non_nullable
as List<PasswordHistoryEntry>,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentMeta>,folderId: freezed == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as String?,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,favorite: null == favorite ? _self.favorite : favorite // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,reprompt: null == reprompt ? _self.reprompt : reprompt // ignore: cast_nullable_to_non_nullable
as bool,trashedAt: freezed == trashedAt ? _self.trashedAt : trashedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,passwordUpdatedAt: freezed == passwordUpdatedAt ? _self.passwordUpdatedAt : passwordUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$Folder {

 String get id; String get name; String? get parentId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Folder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderCopyWith<Folder> get copyWith => _$FolderCopyWithImpl<Folder>(this as Folder, _$identity);

  /// Serializes this Folder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Folder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Folder&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.parentId, _this.parentId) || other.parentId == _this.parentId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Folder;
  return Object.hash(runtimeType,_this.id,_this.name,_this.parentId,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Folder;
  return 'Folder(id: ${_this.id}, name: ${_this.name}, parentId: ${_this.parentId}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $FolderCopyWith<$Res>  {
  factory $FolderCopyWith(Folder value, $Res Function(Folder) _then) = _$FolderCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? parentId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$FolderCopyWithImpl<$Res>
    implements $FolderCopyWith<$Res> {
  _$FolderCopyWithImpl(this._self, this._then);

  final Folder _self;
  final $Res Function(Folder) _then;

/// Create a copy of Folder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? parentId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Folder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Folder].
extension FolderPatterns on Folder {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Folder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Folder() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Folder value)  $default,){
final _that = this;
switch (_that) {
case _Folder():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Folder value)?  $default,){
final _that = this;
switch (_that) {
case _Folder() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? parentId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Folder() when $default != null:
return $default(_that.id,_that.name,_that.parentId,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? parentId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Folder():
return $default(_that.id,_that.name,_that.parentId,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? parentId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Folder() when $default != null:
return $default(_that.id,_that.name,_that.parentId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Folder implements Folder {
  const _Folder({required this.id, required this.name, this.parentId, required this.createdAt, required this.updatedAt});
  factory _Folder.fromJson(Map<String, dynamic> json) => _$FolderFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? parentId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Folder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FolderCopyWith<_Folder> get copyWith => __$FolderCopyWithImpl<_Folder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FolderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Folder&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,parentId,createdAt,updatedAt);
}

@override
String toString() {
    return 'Folder(id: $id, name: $name, parentId: $parentId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$FolderCopyWith<$Res> implements $FolderCopyWith<$Res> {
  factory _$FolderCopyWith(_Folder value, $Res Function(_Folder) _then) = __$FolderCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? parentId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$FolderCopyWithImpl<$Res>
    implements _$FolderCopyWith<$Res> {
  __$FolderCopyWithImpl(this._self, this._then);

  final _Folder _self;
  final $Res Function(_Folder) _then;

/// Create a copy of Folder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? parentId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Folder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Tag {

 String get id; String get name; int get color; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Tag
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TagCopyWith<Tag> get copyWith => _$TagCopyWithImpl<Tag>(this as Tag, _$identity);

  /// Serializes this Tag to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Tag;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tag&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Tag;
  return Object.hash(runtimeType,_this.id,_this.name,_this.color,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Tag;
  return 'Tag(id: ${_this.id}, name: ${_this.name}, color: ${_this.color}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $TagCopyWith<$Res>  {
  factory $TagCopyWith(Tag value, $Res Function(Tag) _then) = _$TagCopyWithImpl;
@useResult
$Res call({
 String id, String name, int color, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$TagCopyWithImpl<$Res>
    implements $TagCopyWith<$Res> {
  _$TagCopyWithImpl(this._self, this._then);

  final Tag _self;
  final $Res Function(Tag) _then;

/// Create a copy of Tag
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Tag(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Tag].
extension TagPatterns on Tag {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tag value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tag() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tag value)  $default,){
final _that = this;
switch (_that) {
case _Tag():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tag value)?  $default,){
final _that = this;
switch (_that) {
case _Tag() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int color,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tag() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int color,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Tag():
return $default(_that.id,_that.name,_that.color,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int color,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Tag() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tag implements Tag {
  const _Tag({required this.id, required this.name, this.color = 0xFF6366F1, required this.createdAt, required this.updatedAt});
  factory _Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  int color;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Tag
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TagCopyWith<_Tag> get copyWith => __$TagCopyWithImpl<_Tag>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TagToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tag&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,color,createdAt,updatedAt);
}

@override
String toString() {
    return 'Tag(id: $id, name: $name, color: $color, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$TagCopyWith<$Res> implements $TagCopyWith<$Res> {
  factory _$TagCopyWith(_Tag value, $Res Function(_Tag) _then) = __$TagCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int color, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$TagCopyWithImpl<$Res>
    implements _$TagCopyWith<$Res> {
  __$TagCopyWithImpl(this._self, this._then);

  final _Tag _self;
  final $Res Function(_Tag) _then;

/// Create a copy of Tag
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Tag(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
