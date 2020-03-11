import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:file/local.dart';

FileSystem fs = LocalFileSystem();

class PubPackage {
  PubPackage(this.name) : assert(name != null);

  final String name;

  Future<String> fetchHomepageUrl() async {
    Uri metadataUri = Uri.https('pub.dev', '/api/packages/$name');
    http.Response response = await http.get(metadataUri);
    if (response.statusCode != 200) {
      throw Exception('Failed fetching $metadataUri response was: ${response.body}');
    }
    Map<String, dynamic> responseMap = jsonDecode(response.body);
    return responseMap['latest']['pubspec']['homepage'];
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
}