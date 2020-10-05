import 'package:file/local.dart';
import 'package:file/src/interface/directory.dart';
import 'package:file/src/interface/file_system.dart';
import 'package:migrate_base/migrate_base.dart';

class SampleMigration extends Migration {
  const SampleMigration();

  @override
  String get optionsHelp => null;

  @override
  Future<bool> isChangeNeeded(Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()}) async {
    return true;
  }

  @override
  Future<VersionBump> migrate(Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()}) async {
    return VersionBump.MAJOR;
  }
}

Future<int> main(List<String> arguments) {
  MigrationRunner runner = MigrationRunner(
    migration: const SampleMigration(),
    executableName: 'migrate_example',
    description: 'A sample migration using the migrate_base package',
  );
  return runner.run(arguments);
}
