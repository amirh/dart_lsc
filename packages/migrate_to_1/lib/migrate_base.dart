import 'package:file/file.dart';

class IsChangeNeededResult {
  IsChangeNeededResult({this.isChangeNeeded, this.error, this.message}) :
        assert((isChangeNeeded == null) != (error == null));

  // null on error.
  final bool isChangeNeeded;

  final String message;

  // null on success.
  final String error;
}

enum VersionBump {
  NO_BUMP,
  PATCH,
  MINOR,
  MAJOR,
}

class MigrationResult {
  MigrationResult({this.versionBump, this.error}) :
        assert((versionBump == null) != (error == null));

  // null on error.
  final VersionBump versionBump;

  // null on success.
  final String error;

}

abstract class Migration {

  // A help string describing how the options string passed to the methods below.
  String get optionsHelp;

  Future<IsChangeNeededResult> isChangeNeeded(Directory packageDir, String dependencyName, String options);

  Future<MigrationResult> migrate(Directory packageDir, String dependencyName, String options);
}