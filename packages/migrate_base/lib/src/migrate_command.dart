import 'dart:async';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:migrate_base/migrate_base.dart';

class MigrateCommand extends Command<int> {
  MigrateCommand(this.migration, {
    @required this.errorSink,
    this.fs = const LocalFileSystem(),
  }) : assert(errorSink != null) {
    argParser.addOption(
        'script_args',
        help: migration.optionsHelp
    );
  }

  final Migration migration;

  final FileSystem fs;

  final IOSink errorSink;

  @override
  String get description => 'Migrate the package at the current directory.';

  @override
  String get name => 'migrate';

  @override
  FutureOr<int> run() async {
    final String dependency = argResults.rest[0];
    VersionBump versionBump;
    try {
      versionBump = await migration.migrate(
          fs.currentDirectory, dependency, argResults['script_args'], fs: fs);
    } catch(e) {
      errorSink.writeln(e.toString());
      return 1;
    }

    print('Migration completed!');
    return versionBumpCode(versionBump);
  }
}
