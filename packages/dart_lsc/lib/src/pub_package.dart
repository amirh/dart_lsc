import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

class PubUrls {
  PubUrls({this.homepage, this.repository});

  final String homepage;
  final String repository;
}

class PubPackage {
  PubPackage({this.name, this.homepage, this.repository, this.latestVersion})
      : assert(name != null);

  final String name;
  final String homepage;
  final String repository;
  Version latestVersion;

  static Future<PubPackage> loadFromIssue(String name) async {
    Uri metadataUri = Uri.https('pub.dev', '/api/packages/$name');
    http.Response response = await http.get(metadataUri);
    if (response.statusCode != 200) {
      throw Exception('Failed fetching $metadataUri response was: ${response.body}');
    }
    Map<String, dynamic> responseMap = jsonDecode(response.body);
    String homepage = responseMap['latest']['pubspec']['homepage'];
    String repository = responseMap['latest']['pubspec']['repository'];
    final String versionString = responseMap['latest']['pubspec']['version'];
    Version version = Version.parse(versionString);
    return PubPackage(
      name: name,
      homepage: homepage,
      repository: repository,
      latestVersion: version
    );
  }

  Future<Directory> fetchLatest(Directory baseDirectory) async {
    Directory targetDir = await baseDirectory.childDirectory(name).create();
    await downloadTarball(targetDir);

    io.ProcessResult result = await io.Process.run(
      'tar',
      ['-zxvf', 'package.tar.gz'],
      workingDirectory: targetDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed extracting tarball for package $name\nstderr: ${result.stderr}\nstdout: ${result.stdout}');
    }
    return targetDir;
  }

  Future<void> downloadTarball(Directory targetDir) async {
      Uri metadataUri = Uri.https('pub.dev', '/api/packages/$name');
      http.Response response = await http.get(metadataUri);
      if (response.statusCode != 200) {
        throw Exception('Failed fetching $metadataUri response was: ${response.body}');
      }
      Map<String, dynamic> responseMap = jsonDecode(response.body);
      String tarballUri = responseMap['latest']['archive_url'];

      response = await http.get(tarballUri);
      if (response.statusCode != 200) {
        throw Exception('Failed fetching $tarballUri response was: ${response.body}');
      }
      File tarballFile = targetDir.childFile('package.tar.gz');
      await tarballFile.writeAsBytes(response.bodyBytes);
  }

  @override
  String toString() {
    return 'PubPackage{name: $name, homepage: $homepage, repository: $repository, latestVersion: $latestVersion}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PubPackage &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latestVersion == other.latestVersion;

  @override
  int get hashCode => name.hashCode ^ latestVersion.hashCode;
}