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


/// Interface defining an LSC migration.
///
/// A `Migration` object applies an update to single Dart/Flutter package at a time.
abstract class Migration {

  // A help string describing the options string passed to the methods below.
  String get optionsHelp;

  /// Checks whether a Dart/Flutter package needs to be updated by this migration.
  ///
  /// The full package source is assumed to be available at `packageDir`.
  ///
  /// When the migration is executed as part of a [dart_lsc](https://github.com/amirh/dart_lsc)
  /// that updates dependent packages, `dependencyName` is the name of the dependency
  /// the migration is considered for. For example a `dart_lsc` change that update
  /// all dependents of package `battery` will invoke `isChangeNeeded` for every
  /// package that depends on `battery` with `depenencyName` set to `"battery"`.
  Future<IsChangeNeededResult> isChangeNeeded(Directory packageDir, String dependencyName, String options);

  /// Applies the migration to a single Dart/Flutter package.
  ///
  /// The full package source is assumed to be available at `packageDir` and will
  /// be modified in place.
  ///
  /// This method does not update the `CHANGELOG.md` file and does not bump
  /// the package's version (the return value indicates which type of [VersionBump]
  /// is needed).
  ///
  /// When the migration is executed as part of a [dart_lsc](https://github.com/amirh/dart_lsc)
  /// that updates dependent packages, `dependencyName` is the name of the dependency
  /// the migration is considered for. For example a `dart_lsc` change that update
  /// all dependents of package `battery` will invoke `migrate` for every
  /// package that depends on `battery` with `depenencyName` set to `"battery"`.
  Future<MigrationResult> migrate(Directory packageDir, String dependencyName, String options);
}