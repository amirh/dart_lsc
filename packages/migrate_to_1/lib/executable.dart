import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:migrate_base/migrate_base.dart';
import 'package:migrate_to_1/src/migrate_to_1.dart';

@visibleForTesting
FileSystem fs = LocalFileSystem();

Future<int> main(List<String> arguments) {
  MigrationRunner runner = MigrationRunner(
    migration: MigrateTo1(),
    executableName: 'migrate_to_1',
    description: 'Migrates a dependent package to support 1.0',
    fs: fs
  );
  return runner.run(arguments);
}
