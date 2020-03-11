import 'dart:convert';
import 'dart:io' show stderr;

import 'package:file/file.dart';
import 'package:file/src/interface/directory.dart';
import 'package:migrate_to_1/migrate_base.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class MigrateTo1 extends Migration {
  @override
  String get optionsHelp => "A JSON map mapping a package to it's earliest version that's compatible with 1.0.0";

  @override
  Future<IsChangeNeededResult> isChangeNeeded(Directory packageDir, String dependencyName, String options) async {
    final File pubspecFile = packageDir.childFile('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      return IsChangeNeededResult(error: "Can't find a pubspec.yaml file in ${packageDir}");
    }

    Map<String, dynamic> compatibleDependencyVersions;
    if (options != null) {
      compatibleDependencyVersions = jsonDecode(options);
    }
    final String compatibleDepenencyVersion = compatibleDependencyVersions[dependencyName];
    if (compatibleDepenencyVersion == null) {
      return IsChangeNeededResult(
          error: "Missing information about the minimal version of $dependencyName that is compatible with 1.0.0"
      );
    }

    final Pubspec pubspec = Pubspec.parse(await pubspecFile.readAsString());
    if (!pubspec.dependencies.containsKey(dependencyName)) {
      return IsChangeNeededResult(
        isChangeNeeded: false,
        message: '${pubspec.name} does not depend on $dependencyName, no migration needed',
      );
    }

    Dependency dependency = pubspec.dependencies[dependencyName];
    if (!(pubspec.dependencies[dependencyName] is HostedDependency)) {
      return IsChangeNeededResult(error: "Can't migrate a non hosted depenency: $dependency");
    }
    HostedDependency hostedDependency = dependency;
    final VersionConstraint constraint = hostedDependency.version;
    if (constraint.allows(Version(1, 0, 0))) {
      return IsChangeNeededResult(
        isChangeNeeded: false,
        message: '${pubspec.name} already allows $dependencyName at version 1.0.0',
      );
    }

    VersionConstraint compatibleDependencyRange =
      VersionConstraint.compatibleWith(Version.parse(compatibleDepenencyVersion));
    if (compatibleDependencyRange.intersect(constraint).isEmpty) {
      return IsChangeNeededResult(
        isChangeNeeded: false,
        message: '${pubspec.name} is not compatible with $dependencyName $compatibleDepenencyVersion',
      );
    }

    return IsChangeNeededResult(isChangeNeeded: true);
  }

  @override
  Future<bool> update(Directory packageDir, String dependency) {
    // TODO: implement update
    throw UnimplementedError();
  }

}