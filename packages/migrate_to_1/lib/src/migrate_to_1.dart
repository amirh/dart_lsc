import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/src/interface/directory.dart';
import 'package:migrate_base/migrate_base.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class MigrateTo1 extends Migration {
  @override
  String get optionsHelp => "A JSON map mapping a package to it's earliest version that's compatible with 1.0.0";

  @override
  Future<bool> isChangeNeeded(Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()}) async {
    final File pubspecFile = packageDir.childFile('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception("Can't find a pubspec.yaml file in ${packageDir}");
    }

    Map<String, dynamic> compatibleDependencyVersions;
    if (options != null) {
      compatibleDependencyVersions = jsonDecode(options);
    }
    final String compatibleDepenencyVersion = compatibleDependencyVersions[dependencyName];
    if (compatibleDepenencyVersion == null) {
      throw Exception(
          "Missing information about the minimal version of $dependencyName that is compatible with 1.0.0"
      );
    }

    final Pubspec pubspec = Pubspec.parse(await pubspecFile.readAsString());
    if (!pubspec.dependencies.containsKey(dependencyName)) {
      print('${pubspec.name} does not depend on $dependencyName, no migration needed');
      return false;
    }

    Dependency dependency = pubspec.dependencies[dependencyName];
    if (!(pubspec.dependencies[dependencyName] is HostedDependency)) {
      throw("Can't migrate a non hosted dependency: $dependency");
    }
    HostedDependency hostedDependency = dependency;
    final VersionConstraint constraint = hostedDependency.version;
    if (constraint.allows(Version(1, 0, 0))) {
      print('${pubspec.name} already allows $dependencyName at version 1.0.0');
      return false;
    }

    VersionConstraint compatibleDependencyRange =
      VersionConstraint.compatibleWith(Version.parse(compatibleDepenencyVersion));
    if (compatibleDependencyRange.intersect(constraint).isEmpty) {
      print('${pubspec.name} is not compatible with $dependencyName $compatibleDepenencyVersion');
      return false;
    }

    return true;
  }

  @override
  Future<VersionBump> migrate(Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()}) async {
    final File pubspecFile = packageDir.childFile('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception("Can't find a pubspec.yaml file in ${packageDir}");
    }
    final Pubspec pubspec = Pubspec.parse(await pubspecFile.readAsString());
    if (!pubspec.dependencies.containsKey(dependencyName)) {
      throw Exception('${pubspec.name} does not depend on $dependencyName, no migration needed');
    }

    Dependency dependency = pubspec.dependencies[dependencyName];
    if (!(pubspec.dependencies[dependencyName] is HostedDependency)) {
      throw Exception("Can't migrate a non hosted depenency: $dependency");
    }
    HostedDependency hostedDependency = dependency;

    VersionRange range = hostedDependency.version;
    String newConstraint = '\'>=${range.min} <2.0.0\'';
    String originalConstraint = RegExp.escape(hostedDependency.version.toString());

    List<String> lines = pubspecFile.readAsLinesSync();
    RegExp needleMatcher = RegExp(
        '^( *${RegExp.escape(dependencyName)}: *)(["\']?$originalConstraint["\']?)(.*)\$'
    );

    int matchesCount = 0;
    for (int i = 0; i < lines.length; i++) {
      RegExpMatch m = needleMatcher.firstMatch(lines[i]);
      if (m != null) {
        lines[i] = '${m[1]}$newConstraint${m[3]}';
        matchesCount++;
      }
    }

    if (matchesCount == 0) {
      throw Exception("Couldn't find $needleMatcher in pubspec.yaml");
    }
    if (matchesCount > 1) {
      throw Exception("Found multiple matches for $needleMatcher in pubspec.yaml");
    }
    pubspecFile.writeAsStringSync(lines.join('\n'));
    return VersionBump.PATCH;
  }

}