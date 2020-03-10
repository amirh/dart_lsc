import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

FileSystem fs = LocalFileSystem();

Future<int> main(List<String> arguments) {
  final CommandRunner runner = CommandRunner<int>('migrate_to_1', 'Migrates a dependent package to support 1.0')
      ..addCommand(ValidateCommand());
  return runner.run(arguments);
}

class ValidateCommand extends Command<int> {
  @override
  String get description => 'validate the a dependent package has been updated to support 1.0';

  @override
  String get name => 'validate';

  @override
  String get invocation {
    var parents = [name];
    for (var command = parent; command != null; command = command.parent) {
      parents.add(command.name);
    }
    parents.add(runner.executableName);

    var invocation = parents.reversed.join(' ');
    return '$invocation <dependency_that_is_updated_to_1.0> <dependency_latets_version>';
  }

  @override
  FutureOr<int> run() async {
    final File pubspecFile = fs.currentDirectory.childFile('pubspec.yaml');
    if (!await pubspecFile.exists()) {
      stderr.write("Can't find a pubspec.yaml file in ${fs.currentDirectory}");
      return 1;
    }

    final String package = argResults.rest[0];
    final String version = argResults.rest[1];

    final Pubspec pubspec = Pubspec.parse(await pubspecFile.readAsString());
    if (!pubspec.dependencies.containsKey(package)) {
      print('${pubspec.name} does not depend on $package, no migration needed');
      return 0;
    }

    Dependency dependency = pubspec.dependencies[package];
    if (!(pubspec.dependencies['share'] is HostedDependency)) {
      stderr.write("Can't migrate a non hosted depenency: $dependency");
      return 1;
    }
    HostedDependency hostedDependency = dependency;
    final VersionConstraint constraint = hostedDependency.version;
    if (constraint.allows(Version(1, 0, 0))) {
      return 0;
    }

    if (!constraint.allows(Version.parse(version))) {
      print('${pubspec.name} is not compatible with $package $version');
      return 0;
    }
    return 2;
  }
}
