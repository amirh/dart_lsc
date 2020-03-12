import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:migrate_to_1/executable.dart' as executable;
import 'package:migrate_to_1/migrate_base.dart';
import 'package:migrate_to_1/src/global.dart' show fs;
import 'package:migrate_to_1/src/migrate_to_1.dart';
import 'package:test/test.dart';

final String needsUpdatePubspec = '''
name: sample_dependent
description: Description.
version: 1.2.3

environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  share: ^0.6.2+1

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';

final String updatedPubspec1 = '''
name: sample_dependent
description: Description.
version: 1.2.3

environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  share: '>=0.6.2+1 <2.0.0'

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';

final String pubspecWithNoShareDependency = '''
name: sample_dependent
description: Description.
version: 1.2.3

environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';

final String multipleShareMatchesPubspec = '''
name: sample_dependent
description: Description.
version: 1.2.3

environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  share: ^0.6.2+1

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
  share: ^0.6.2+1
''';

final String quotedConstraintPubspec = '''
name: sample_dependent
description: Description.
version: 1.2.3

environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  share: '^0.6.2+1'

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';

final String doubleQuotedConstraintPubspec = '''
name: sample_dependent
description: Description.
version: 1.2.3

environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
  share: '^0.6.2+1'

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
''';

void main() {
  Map<String, String> compatibleVersions = {
    'share': '0.6.5+4',
  };

  String scriptArgs() => '--script_args=${jsonEncode(compatibleVersions)}';

  setUp(() {
    fs = MemoryFileSystem();
  });
  test('no pubspec', () async {
    final retval = await executable.main(['is_change_needed', 'share', scriptArgs()]);
    expect(retval, 1);
  });

  test('pubspec needs update', () async {
    final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
    await pubspecFile.writeAsString(needsUpdatePubspec);
    final retval = await executable.main(['is_change_needed', 'share', scriptArgs()]);
    expect(retval, 2);
  });

  test('compatible version is earlier than current minimum', () async {
    final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
    await pubspecFile.writeAsString(needsUpdatePubspec);

    final String prevShareValue = compatibleVersions['share'];
    compatibleVersions['share'] = '0.6.0';
    final retval = await executable.main(['is_change_needed', 'share', scriptArgs()]);
    compatibleVersions['share'] = prevShareValue;
    expect(retval, 2);
  });

  test('pubspec does not need update', () async {
    final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
    await pubspecFile.writeAsString(updatedPubspec1);
    final retval = await executable.main(['is_change_needed', 'share', scriptArgs()]);
    expect(retval, 0);
  });

  test('pubspec without the target depenency', () async {
    final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
    await pubspecFile.writeAsString(pubspecWithNoShareDependency);
    final retval = await executable.main(['is_change_needed', 'share', scriptArgs()]);
    expect(retval, 0);
  });

  test('pubspec requires older version', () async {
    final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
    await pubspecFile.writeAsString(needsUpdatePubspec);
    final String prevShareValue = compatibleVersions['share'];
    compatibleVersions['share'] = '0.7.1';
    final retval = await executable.main(['is_change_needed', 'share', scriptArgs()]);
    compatibleVersions['share'] = prevShareValue;
    expect(retval, 0);
  });

  group('migrate', () {
    test('succesful migration', () async {
      final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
      await pubspecFile.writeAsString(needsUpdatePubspec);
      final MigrateTo1 migration = MigrateTo1();
      final MigrationResult migrationResult = await migration.migrate(
          fs.currentDirectory, 'share', jsonEncode(compatibleVersions)
      );
      expect(migrationResult.versionBump, VersionBump.PATCH);
      expect(migrationResult.error, isNull);
      String migratedPubspec = pubspecFile.readAsStringSync();
      expect(migratedPubspec, updatedPubspec1);
    });

    test('quoted constraint', () async {
      final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
      await pubspecFile.writeAsString(quotedConstraintPubspec);
      final MigrateTo1 migration = MigrateTo1();
      final MigrationResult migrationResult = await migration.migrate(
          fs.currentDirectory, 'share', jsonEncode(compatibleVersions)
      );
      expect(migrationResult.versionBump, VersionBump.PATCH);
      expect(migrationResult.error, isNull);
      String migratedPubspec = pubspecFile.readAsStringSync();
      expect(migratedPubspec, updatedPubspec1);
    });

    test('double quoted constraint', () async {
      final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
      await pubspecFile.writeAsString(doubleQuotedConstraintPubspec);
      final MigrateTo1 migration = MigrateTo1();
      final MigrationResult migrationResult = await migration.migrate(
          fs.currentDirectory, 'share', jsonEncode(compatibleVersions)
      );
      expect(migrationResult.versionBump, VersionBump.PATCH);
      expect(migrationResult.error, isNull);
      String migratedPubspec = pubspecFile.readAsStringSync();
      expect(migratedPubspec, updatedPubspec1);
    });

    test('multiple matches', () async {
      final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
      await pubspecFile.writeAsString(multipleShareMatchesPubspec);
      final MigrateTo1 migration = MigrateTo1();
      final MigrationResult migrationResult = await migration.migrate(
          fs.currentDirectory, 'share', jsonEncode(compatibleVersions)
      );
      expect(migrationResult.error, isNotNull);
      String migratedPubspec = pubspecFile.readAsStringSync();
      // nothing changed
      expect(migratedPubspec, multipleShareMatchesPubspec);
    });

    test('no matches', () async {
      final File pubspecFile = await fs.currentDirectory.childFile('pubspec.yaml').create();
      await pubspecFile.writeAsString(pubspecWithNoShareDependency);
      final MigrateTo1 migration = MigrateTo1();
      final MigrationResult migrationResult = await migration.migrate(
          fs.currentDirectory, 'share', jsonEncode(compatibleVersions)
      );
      expect(migrationResult.error, isNotNull);
      String migratedPubspec = pubspecFile.readAsStringSync();
      // nothing changed
      expect(migratedPubspec, pubspecWithNoShareDependency);
    });
  });
}


