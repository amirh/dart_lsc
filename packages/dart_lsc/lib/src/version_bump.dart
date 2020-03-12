import 'package:file/file.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

/// bumpType is one of: 11 (patch), 12 (minor), 13 (major).
Future<String> bumpVersion(Directory packageDir, int bumpType, String changelogEntryBody) async {
  final File pubspecFile = packageDir.childFile('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    return "Can't find a pubspec.yaml file in ${packageDir}";
  }
  final Pubspec pubspec = Pubspec.parse(await pubspecFile.readAsString());
  if (pubspec == null) {
    return "Can't parse pubspec.yaml";
  }

  Version newVersion;
  switch (bumpType) {
    case 11:
      newVersion = pubspec.version.nextPatch;
      break;
    case 12:
      newVersion = pubspec.version.nextMinor;
      break;
    case 13:
      newVersion = pubspec.version.nextMajor;
      break;
    default:
      return "Unknown version bump type: $bumpType";
  }
  String originalVersion = RegExp.escape(pubspec.version.toString());

  List<String> lines = pubspecFile.readAsLinesSync();
  RegExp needleMatcher = RegExp(
      '^( *version: *)(["\']?$originalVersion["\']?)(.*)\$'
  );

  int matchesCount = 0;
  for (int i = 0; i < lines.length; i++) {
    RegExpMatch m = needleMatcher.firstMatch(lines[i]);
    if (m != null) {
      lines[i] = '${m[1]}$newVersion${m[3]}';
      matchesCount++;
    }
  }

  if (matchesCount == 0) {
    return "Failed locating version key in pubspec.yaml";
  }
  if (matchesCount > 1) {
    return "Found multiple matches for $needleMatcher in pubspec.yaml";
  }
  await pubspecFile.writeAsString(lines.join('\n'));
  return updateChangelog(packageDir, newVersion.toString(), changelogEntryBody);
}

Future<String> updateChangelog(Directory packageDir, String newVersion, String changelogEntryBody) async {
  final File changelogFile = packageDir.childFile('CHANGELOG.md');
  if (!changelogFile.existsSync()) {
    return "Can't find $changelogFile";
  }
  final StringBuffer newContents = StringBuffer();
  newContents.write('## $newVersion\n\n');
  newContents.write('$changelogEntryBody\n\n');
  newContents.write(await changelogFile.readAsString());
  await changelogFile.writeAsString(newContents.toString());
  return null;
}
