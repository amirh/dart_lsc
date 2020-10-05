import 'package:file/file.dart';
import 'package:file/local.dart';

/// Types of semver version bump.
enum VersionBump {
  NO_BUMP,
  PATCH,
  MINOR,
  MAJOR,
}

/// Maps a [VersionBump] values to command line process exit code.
int versionBumpCode(VersionBump bump) => bump.index + 10;

/// Maps a process exit code to a [VersionBump] value.
VersionBump codeToVersionBump(int code) => VersionBump.values[code - 10];

/// Interface defining an LSC migration.
///
/// A `Migration` object applies an update to single Dart/Flutter package at a time.
abstract class Migration {
  const Migration();

  // A help string describing the options string passed to the methods below.
  String get optionsHelp;

  /// Checks whether a Dart/Flutter package needs to be updated by this migration.
  ///
  /// The full package source is assumed to be available at `packageDir`.
  ///
  /// {@template dependency_name}
  /// When the migration is executed as part of a [dart_lsc](https://github.com/amirh/dart_lsc/tree/master/packages/dart_lsc)
  /// that updates dependent packages, `dependencyName` is the name of the dependency
  /// the migration is considered for. For example a `dart_lsc` change that update
  /// all dependents of package `battery` will invoke `isChangeNeeded` for every
  /// package that depends on `battery` with `depenencyName` set to `"battery"`.
  /// {@endtemplate}
  ///
  /// Returns true if a change is needed false otherwise, throws an exception on error.
  Future<bool> isChangeNeeded(Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()});

  /// Applies the migration to a single Dart/Flutter package.
  ///
  /// The full package source is assumed to be available at `packageDir` and will
  /// be modified in place.
  ///
  /// This method does not update the `CHANGELOG.md` file and does not bump
  /// the package's version (the return value indicates which type of [VersionBump]
  /// is needed).
  ///
  /// {@macro dependency_name}
  ///
  /// Returns:
  ///   * [VersionBump.MAJOR] if the migration applied a breaking change and
  ///     the migrated package should get a major version bump.
  ///   * [VersionBump.MINOR] if the migration resulted added a new feature
  ///     and the migrated package should get a minor version bump.
  ///   * [VersionBump.PATCH] if the migration resulted in fixing a bug in a
  ///     backward compatible way and the migrated package should get a patch
  ///     version bump.
  ///   * [VersionBump.NO_BUMP] if following the migration the version of the
  ///     migrated package does not need to be changed.
  Future<VersionBump> migrate(Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()});
}
