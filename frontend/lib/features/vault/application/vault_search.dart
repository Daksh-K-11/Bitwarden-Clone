import '../domain/item_type.dart';
import '../domain/vault_models.dart';

enum VaultSection { all, favorites, recent, archive, trash }

enum SortOrder { name, recentlyModified, recentlyCreated }

class VaultFilter {
  const VaultFilter({
    this.section = VaultSection.all,
    this.query = '',
    this.types = const {},
    this.folderId,
    this.includeSubfolders = true,
    this.tagIds = const {},
    this.favoritesOnly = false,
    this.modifiedWithinDays,
    this.withTotpOnly = false,
    this.sort = SortOrder.name,
  });

  final VaultSection section;
  final String query;
  final Set<ItemType> types;

  /// '' = items without a folder; null = any folder.
  final String? folderId;
  final bool includeSubfolders;

  /// Items must carry *all* selected tags.
  final Set<String> tagIds;
  final bool favoritesOnly;
  final int? modifiedWithinDays;
  final bool withTotpOnly;
  final SortOrder sort;

  bool get hasRefinements =>
      types.isNotEmpty || folderId != null || tagIds.isNotEmpty || favoritesOnly || modifiedWithinDays != null;

  VaultFilter copyWith({
    VaultSection? section,
    String? query,
    Set<ItemType>? types,
    String? Function()? folderId,
    Set<String>? tagIds,
    bool? favoritesOnly,
    int? Function()? modifiedWithinDays,
    bool? withTotpOnly,
    SortOrder? sort,
  }) => VaultFilter(
    section: section ?? this.section,
    query: query ?? this.query,
    types: types ?? this.types,
    folderId: folderId != null ? folderId() : this.folderId,
    includeSubfolders: includeSubfolders,
    tagIds: tagIds ?? this.tagIds,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    modifiedWithinDays: modifiedWithinDays != null ? modifiedWithinDays() : this.modifiedWithinDays,
    withTotpOnly: withTotpOnly ?? this.withTotpOnly,
    sort: sort ?? this.sort,
  );
}

/// In-memory search index.
///
/// Built from decrypted items when the vault unlocks and discarded on lock.
/// It is never persisted. Only non-secret fields are indexed: name,
/// non-sensitive template fields (username, email, cardholder, SSID...),
/// URLs, non-hidden custom fields, folder and tag names, and - only if the
/// user enables it - notes. Passwords, card numbers, CVVs, private keys,
/// recovery phrases, TOTP secrets and hidden custom fields are never indexed.
class SearchIndex {
  SearchIndex._(this._haystacks);

  final Map<String, String> _haystacks;

  factory SearchIndex.build(
    Iterable<VaultItem> items, {
    required Map<String, Folder> folders,
    required Map<String, Tag> tags,
    required bool includeNotes,
  }) {
    final map = <String, String>{};
    for (final item in items) {
      final parts = <String>[item.name, item.type.template.label];
      final template = item.type.template;
      for (final spec in template.fields) {
        if (spec.searchable && !spec.isSensitive) {
          final v = item.fields[spec.key];
          if (v != null && v.isNotEmpty) parts.add(v);
        }
      }
      parts.addAll(item.uris);
      for (final f in item.customFields) {
        if (f.isSensitive) continue;
        parts.add(f.name);
        if (f.type != CustomFieldType.boolean) parts.add(f.value);
      }
      if (item.folderId != null) parts.add(folders[item.folderId]?.name ?? '');
      for (final t in item.tagIds) {
        parts.add(tags[t]?.name ?? '');
      }
      if (includeNotes) parts.add(item.notes);
      map[item.id] = parts.join('\u0000').toLowerCase();
    }
    return SearchIndex._(map);
  }

  static const empty = _EmptyIndex();

  bool matches(String itemId, List<String> terms) {
    final h = _haystacks[itemId];
    if (h == null) return false;
    for (final t in terms) {
      if (!h.contains(t)) return false;
    }
    return true;
  }
}

class _EmptyIndex implements SearchIndex {
  const _EmptyIndex();
  @override
  Map<String, String> get _haystacks => const {};
  @override
  bool matches(String itemId, List<String> terms) => false;
}

Set<String> folderWithDescendants(String folderId, Map<String, Folder> folders) {
  final out = {folderId};
  var changed = true;
  while (changed) {
    changed = false;
    for (final f in folders.values) {
      if (f.parentId != null && out.contains(f.parentId) && out.add(f.id)) changed = true;
    }
  }
  return out;
}

List<VaultItem> applyFilter(
  Iterable<VaultItem> items,
  VaultFilter filter, {
  required SearchIndex index,
  required Map<String, Folder> folders,
  List<String> recentIds = const [],
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final terms = filter.query.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  Set<String>? folderSet;
  if (filter.folderId != null && filter.folderId!.isNotEmpty) {
    folderSet = filter.includeSubfolders ? folderWithDescendants(filter.folderId!, folders) : {filter.folderId!};
  }

  final result = items.where((i) {
    switch (filter.section) {
      case VaultSection.trash:
        if (!i.isTrashed) return false;
      case VaultSection.archive:
        if (i.isTrashed || !i.archived) return false;
      case VaultSection.favorites:
        if (i.isTrashed || i.archived || !i.favorite) return false;
      case VaultSection.recent:
        if (i.isTrashed || !recentIds.contains(i.id)) return false;
      case VaultSection.all:
        if (i.isTrashed || i.archived) return false;
    }
    if (filter.types.isNotEmpty && !filter.types.contains(i.type)) return false;
    if (filter.folderId != null) {
      if (filter.folderId!.isEmpty) {
        if (i.folderId != null) return false;
      } else if (!folderSet!.contains(i.folderId)) {
        return false;
      }
    }
    if (filter.tagIds.isNotEmpty && !filter.tagIds.every(i.tagIds.contains)) return false;
    if (filter.favoritesOnly && !i.favorite) return false;
    if (filter.withTotpOnly && (i.totp ?? '').isEmpty) return false;
    if (filter.modifiedWithinDays != null && t.difference(i.updatedAt).inDays > filter.modifiedWithinDays!) {
      return false;
    }
    if (terms.isNotEmpty && !index.matches(i.id, terms)) return false;
    return true;
  }).toList();

  if (filter.section == VaultSection.recent) {
    result.sort((a, b) => recentIds.indexOf(a.id).compareTo(recentIds.indexOf(b.id)));
    return result;
  }
  switch (filter.sort) {
    case SortOrder.name:
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SortOrder.recentlyModified:
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case SortOrder.recentlyCreated:
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  return result;
}
