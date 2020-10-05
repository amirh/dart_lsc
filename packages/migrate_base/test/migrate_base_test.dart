import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:migrate_base/migrate_base.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'capturing_run.dart';


void main() {
  group('migrate', () {
    test('no bump exit code', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.NO_BUMP);
      expect(await runMigration(migration), versionBumpCode(VersionBump.NO_BUMP));
    });
    test('patch bump exit code', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.PATCH);
      expect(await runMigration(migration), versionBumpCode(VersionBump.PATCH));
    });
    test('minor bump exit code', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.MINOR);
      expect(await runMigration(migration), versionBumpCode(VersionBump.MINOR));
    });
    test('major bump exit code', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.MAJOR);
      expect(await runMigration(migration), versionBumpCode(VersionBump.MAJOR));
    });
    test('success', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.NO_BUMP);
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test');
      List<String> result = await runCapturingPrint(runner, <String>['migrate', 'package_foo']);
      expect(result, orderedEquals(<String>[
        'Migration completed!'
      ]));
    });
    test('migration error', () async {
      final FakeMigration migration = FakeMigration.fromFunctions(
          isChangeNeededFn: () => true,
          versionBumpFn: () { throw Exception('failed to migrate'); }
      );
      MockStderr mockStderr = MockStderr();
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test', errorSink: mockStderr);
      await runCapturingPrint(runner, <String>['migrate', 'package_foo']);
      verify(mockStderr.writeln('Exception: failed to migrate')).called(1);
    });
    group('parameters',()
    {
      test('no script_args', () async {
        MockMigration migration = MockMigration();
        when(migration.isChangeNeeded(any, any, any))
            .thenAnswer((Invocation realInvocation) =>
        Future<bool>.value(true));
        when(migration.migrate(any, any, any, fs: anyNamed('fs')))
            .thenAnswer((Invocation realInvocation) =>
        Future<VersionBump>.value(VersionBump.NO_BUMP));

        fs.currentDirectory = fs.directory('/tmp/package_foo')
          ..createSync(recursive: true);

        MigrationRunner runner = MigrationRunner(
            migration: migration, executableName: 'test', fs: fs);
        await runner.run(<String>['migrate', 'foo']);

        String actual_package_path = verify(
            migration.migrate(captureAny, 'foo', null, fs: fs)).captured[0]
            .path;
        expect(actual_package_path, '/tmp/package_foo');
      });

      test('script_args', () async {
        MockMigration migration = MockMigration();
        when(migration.isChangeNeeded(any, any, any))
            .thenAnswer((Invocation realInvocation) =>
        Future<bool>.value(true));
        when(migration.migrate(any, any, any, fs: anyNamed('fs')))
            .thenAnswer((Invocation realInvocation) =>
        Future<VersionBump>.value(VersionBump.NO_BUMP));

        fs.currentDirectory = fs.directory('/tmp/package_foo')
          ..createSync(recursive: true);

        MigrationRunner runner = MigrationRunner(
            migration: migration, executableName: 'test', fs: fs);
        await runner.run(<String>['migrate', 'foo', '--script_args=a,b']);

        String actual_package_path = verify(
            migration.migrate(captureAny, 'foo', 'a,b', fs: fs)).captured[0]
            .path;
        expect(actual_package_path, '/tmp/package_foo');
      });
    });
  });

  group('is_change_needed', () {
    test('change needed', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.NO_BUMP);
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test');
      List<String> result = await runCapturingPrint(runner, <String>['is_change_needed', 'package_foo']);
      expect(result, orderedEquals(<String>[
        'Migration needed.'
      ]));
    });
    test('change needed exit code', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: true, versionBump: VersionBump.NO_BUMP);
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test');
      int exitCode = await runner.run(<String>['is_change_needed', 'package_foo']);
      expect(exitCode, 2);
    });
    test('change not needed stdout', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: false, versionBump: VersionBump.NO_BUMP);
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test');
      List<String> result = await runCapturingPrint(runner, <String>['is_change_needed', 'package_foo']);
      expect(result, orderedEquals(<String>[
        'No migration needed.'
      ]));
    });
    test('change not needed exit code', () async {
      final FakeMigration migration = FakeMigration(isChangeNeeded: false, versionBump: VersionBump.NO_BUMP);
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test');
      int exitCode = await runner.run(<String>['is_change_needed', 'package_foo']);
      expect(exitCode, 0);
    });
    test('error', () async {
      final FakeMigration migration = FakeMigration.fromFunctions(
          isChangeNeededFn: () { throw Exception('failed'); },
          versionBumpFn: () => VersionBump.NO_BUMP,
      );
      MockStderr mockStderr = MockStderr();
      MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test', errorSink: mockStderr);
      await runCapturingPrint(runner, <String>['is_change_needed', 'package_foo']);
      verify(mockStderr.writeln('Exception: failed')).called(1);
    });
    group('parameters',()
    {
      test('no script_args', () async {
        MockMigration migration = MockMigration();
        when(migration.isChangeNeeded(any, any, any))
            .thenAnswer((Invocation realInvocation) =>
        Future<bool>.value(true));
        when(migration.migrate(any, any, any, fs: anyNamed('fs')))
            .thenAnswer((Invocation realInvocation) =>
        Future<VersionBump>.value(VersionBump.NO_BUMP));

        fs.currentDirectory = fs.directory('/tmp/package_foo')
          ..createSync(recursive: true);

        MigrationRunner runner = MigrationRunner(
            migration: migration, executableName: 'test', fs: fs);
        await runner.run(<String>['migrate', 'foo']);

        String actual_package_path = verify(
            migration.migrate(captureAny, 'foo', null, fs: fs)).captured[0]
            .path;
        expect(actual_package_path, '/tmp/package_foo');
      });

      test('script_args', () async {
        MockMigration migration = MockMigration();
        when(migration.isChangeNeeded(any, any, any))
            .thenAnswer((Invocation realInvocation) =>
        Future<bool>.value(true));
        when(migration.migrate(any, any, any, fs: anyNamed('fs')))
            .thenAnswer((Invocation realInvocation) =>
        Future<VersionBump>.value(VersionBump.NO_BUMP));

        fs.currentDirectory = fs.directory('/tmp/package_foo')
          ..createSync(recursive: true);

        MigrationRunner runner = MigrationRunner(
            migration: migration, executableName: 'test', fs: fs);
        await runner.run(<String>['migrate', 'foo', '--script_args=a,b']);

        String actual_package_path = verify(
            migration.migrate(captureAny, 'foo', 'a,b', fs: fs)).captured[0]
            .path;
        expect(actual_package_path, '/tmp/package_foo');
      });
    });
  });
}

class MockMigration extends Mock implements Migration {}

class FakeMigration extends Migration {
  FakeMigration.fromFunctions(
      {@required this.isChangeNeededFn, @required this.versionBumpFn});

  FakeMigration(
      {@required bool isChangeNeeded, @required VersionBump versionBump})
      : this.fromFunctions(
    isChangeNeededFn: () => isChangeNeeded,
    versionBumpFn: () => versionBump,
  );

  bool Function() isChangeNeededFn;

  VersionBump Function() versionBumpFn;

  @override
  Future<bool> isChangeNeeded(
      Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()}) async {
    return isChangeNeededFn();
  }

  @override
  Future<VersionBump> migrate(
      Directory packageDir, String dependencyName, String options, {FileSystem fs = const LocalFileSystem()}) async {
    return versionBumpFn();
  }

  @override
  String get optionsHelp => null;
}

FileSystem fs = MemoryFileSystem();
Future<Directory> createPackage({String versionString}) async {
  Directory packageDir = await fs.systemTempDirectory.createTemp();
  File pubspec = packageDir.childFile('pubspec.yaml');
  await pubspec.writeAsString('version: $versionString');
  return packageDir;
}

Future<int> runMigration(Migration migration) async {
  MigrationRunner runner = MigrationRunner(migration: migration, executableName: 'test');
  int exitCode = await runner.run(<String>['migrate', 'package_foo']);
  return exitCode;
}

class MockStderr extends Mock implements IOSink {}
