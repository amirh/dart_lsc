import 'dart:async';
import 'dart:io' show stderr;

import 'package:args/command_runner.dart';
import 'package:migrate_to_1/migrate_base.dart';
import 'package:migrate_to_1/src/migrate_to_1.dart';

import 'src/global.dart' show fs;

Future<int> main(List<String> arguments) {
  Migration migration = MigrateTo1();
  final CommandRunner runner = CommandRunner<int>('migrate_to_1', 'Migrates a dependent package to support 1.0')
    ..addCommand(IsChangeNeededCommand(migration))
    ..addCommand(MigrateCommand(migration));
  return runner.run(arguments);
}


class IsChangeNeededCommand extends Command<int> {
  IsChangeNeededCommand(this.migration) {
    argParser.addOption(
        'script_args',
        help: migration.optionsHelp
    );
  }

  final Migration migration;

  @override
  String get description => 'Check if a migration is needed for the package at the current directory';

  @override
  String get name => 'is_change_needed';

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
    final String dependency = argResults.rest[0];
    IsChangeNeededResult result = await migration.isChangeNeeded(fs.currentDirectory, dependency, argResults['script_args']);

    if (result.error != null) {
      stderr.write(result.error);
      return 1;
    }
    if (result.isChangeNeeded) {
      return 2;
    } else {
      print(result.message);
      return 0;
    }
  }

}
class MigrateCommand extends Command<int> {
  MigrateCommand(this.migration) {
    argParser.addOption(
        'script_args',
        help: migration.optionsHelp
    );
  }

  final Migration migration;

  @override
  String get description => 'Migrate the package at the current directory.';

  @override
  String get name => 'migrate';

  @override
  FutureOr<int> run() async {
    final String dependency = argResults.rest[0];
    MigrationResult result = await migration.migrate(fs.currentDirectory, dependency, argResults['script_args']);

    if (result.error != null) {
      stderr.write(result.error);
      return 1;
    }

    Map<VersionBump, int> versionBumpCodes = {
      VersionBump.NO_BUMP: 10,
      VersionBump.PATCH: 11,
      VersionBump.MINOR: 12,
      VersionBump.MAJOR: 13,
    };

    return versionBumpCodes[result.versionBump];
  }
}
