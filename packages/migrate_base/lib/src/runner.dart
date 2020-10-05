import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:migrate_base/migrate_base.dart';
import 'package:migrate_base/src/is_change_needed_command.dart';
import 'package:migrate_base/src/migrate_command.dart';

class MigrationRunner {
  MigrationRunner({
    @required this.migration,
    @required this.executableName,
    this.description = '',
    IOSink errorSink,
    this.fs = const LocalFileSystem(),
  }) : assert(migration != null),
       assert(executableName != null) {
    _errorSink = errorSink ?? stderr;
  }

  final Migration migration;

  final String executableName;

  final String description;

  final FileSystem fs;

  IOSink _errorSink;
  IOSink get errorSink => _errorSink;

  Future<int> run(Iterable<String> arguments) {
    final CommandRunner<int> runner = CommandRunner<int>(executableName, description);
    runner.addCommand(MigrateCommand(migration, errorSink: errorSink, fs: fs));
    runner.addCommand(IsChangeNeededCommand(migration, errorSink: errorSink, fs: fs));
    return runner.run(arguments);
  }
}