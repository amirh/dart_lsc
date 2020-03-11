import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:migrate_to_1/executable.dart' as executable;
import 'package:migrate_to_1/src/global.dart' show fs;
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
}
