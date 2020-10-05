import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:migrate_base/migrate_base.dart';

class IsChangeNeededCommand extends Command<int> {
  IsChangeNeededCommand(this.migration, {
    @required this.errorSink,
    this.fs = const LocalFileSystem(),
  }) {
    argParser.addOption(
        'script_args',
        help: migration.optionsHelp
    );
  }

  final Migration migration;

  final FileSystem fs;

  final IOSink errorSink;

  @override
  String get description => 'Check if a migration is needed for the package at the current directory';

  @override
  String get name => 'is_change_needed';

  @override
  FutureOr<int> run() async {
    final String dependency = argResults.rest[0];
    bool isChangeNeeded;
    try {
      isChangeNeeded = await migration.isChangeNeeded(fs.currentDirectory, dependency, argResults['script_args']);
    } catch(e) {
      errorSink.writeln(e.toString());
      return 1;
    }
    if (!isChangeNeeded) {
      print('No migration needed.');
    } else {
      print('Migration needed.');
    }
    return isChangeNeeded ? 2 : 0;
  }
}
