Iterable<String> tagPathPrefixes(String tag) sync* {
  final parts = tag.split('/');
  for (var length = 1; length <= parts.length; length++) {
    yield parts.take(length).join('/');
  }
}

bool tagPathContains(String parent, String tag) =>
    tag == parent || tag.startsWith('$parent/');

String renamedTagPath(String tag, String oldName, String newName) =>
    tagPathContains(oldName, tag)
    ? '$newName${tag.substring(oldName.length)}'
    : tag;

String tagPathLabel(String tag) => tag.split('/').last;

String inferredTagPath(String name, Iterable<String> choices) {
  if (choices.contains(name) || name.contains('/')) return name;
  final sameLabels = choices.where((tag) => tagPathLabel(tag) == name).toList();
  if (sameLabels.length == 1) return sameLabels.single;
  final parents = choices
      .where((tag) => !tag.contains('/') && name.contains(tag))
      .toList();
  return parents.length == 1 ? '${parents.single}/$name' : name;
}
