import 'dart:io';

import 'package:dart_lsc/src/pub_package.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import 'global.dart';

class GitHubGitRepository {
  GitHubGitRepository(this.owner, this.repository, this.path);

  final String owner;
  final String repository;
  final String path;

  static GitHubGitRepository fromPubUrl(String homepage, String repository) {
    return _fromUrl(homepage) ?? _fromUrl(repository);
  }

  static GitHubGitRepository _fromUrl(String url) {
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch(FormatException) {
      return null;
    }

    if (!['github.com', 'www.github.com'].contains(uri.authority)) {
      return null;
    }

    if (uri.pathSegments.length < 2) {
      return null;
    }

    final String owner = uri.pathSegments[0];
    String repository = uri.pathSegments[1];
    String prefix = '/$owner/$repository';
    String path = '';
    if (uri.pathSegments.length > 3 && ['tree', 'blob'].contains(uri.pathSegments[2])) {
      prefix = '$prefix/${uri.pathSegments[2]}/${uri.pathSegments[3]}/';
       path = uri.path.substring(prefix.length);
    };


    if (repository.endsWith('.git')) {
      repository = repository.substring(0, repository.length - 4);
    }

    return GitHubGitRepository(owner, repository, path);
  }

  Future<GitClone> clone(Directory workingDirectory, String package) async {
    String gitUri = 'git@github.com:$owner/$repository.git';
    final ProcessResult result = await Process.run(
        'git',
        ['clone', gitUri],
        workingDirectory: workingDirectory.path,
    );
    if (result.exitCode != 0) {
      throw Exception('git clone failed for $gitUri');
    }

    Directory cloneDirectory = workingDirectory.childDirectory(repository);

    String packagePath = await findPubspecDirectory(cloneDirectory, package);

    return GitClone(cloneDirectory, cloneDirectory.childDirectory(packagePath));
  }

  static Future<String> findPubspecDirectory(Directory directory, String packageName) async {
    final ProcessResult result = await Process.run(
      'git',
      ['grep', 'name: *$packageName *\$', '--', 'pubspec.yaml', '**/pubspec.yaml'],
      workingDirectory: directory.path,
    );

    if (result.exitCode == 1) {
      throw Exception('Can\'t find pubspec for package $packageName in repository');
    }
    if (result.exitCode != 0) {
      throw Exception('git grep failed in ${directory.path}. stderr: ${result.stderr}');
    }

    final List<String> potentialPubspecs = result.stdout
        .split('\n')
        .where((String element) => element.contains('pubspec.yaml:') && !element.contains('example/pubspec.yaml:'))
        .toList();
    if (potentialPubspecs.length > 1) {
      throw Exception("Found multiple potential pubspecs for $packageName: $potentialPubspecs");
    }

    final String pubspecPath = '/${potentialPubspecs[0].split(':').first}';

    return pubspecPath.substring(0, pubspecPath.length - '/pubspec.yaml'.length);
  }

  @override
  String toString() {
    return 'GitHubGitRepository{owner: $owner, repository: $repository, path: $path}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubGitRepository &&
          runtimeType == other.runtimeType &&
          owner == other.owner &&
          repository == other.repository &&
          path == other.path;

  @override
  int get hashCode => owner.hashCode ^ repository.hashCode ^ path.hashCode;
}

class GitClone {
  GitClone(this.baseDirectory, this.packageDirectory);

  final Directory baseDirectory;
  final Directory packageDirectory;

  File get pubspec => packageDirectory.childFile('pubspec.yaml');

  Future<String> addAndCommit(String msg) async {
    ProcessResult result = await Process.run(
      'git',
      ['add', '.'],
      workingDirectory: baseDirectory.path,
    );
    if (result.exitCode != 0) {
      print('git add stdout: ${result.stdout}');
      print('git add stderr: ${result.stderr}');
      return 'git add failed for ${baseDirectory.basename}';
    }

    result = await Process.run(
      'git',
      ['commit', '-m', msg],
      workingDirectory: baseDirectory.path,
    );
    if (result.exitCode != 0) {
      print('git commit stdout: ${result.stdout}');
      print('git commit stderr: ${result.stderr}');
      return 'git commit failed for ${baseDirectory.basename}';
    }
    return null;
  }

  void addRemote(String name, String uri) async {
    ProcessResult result = await Process.run(
      'git',
      ['remote', 'add', name, uri],
      workingDirectory: baseDirectory.path,
    );
    if (result.exitCode != 0) {
      print('git add stdout: ${result.stdout}');
      print('git add stderr: ${result.stderr}');
      throw Exception('git remote add failed for $uri');
    }
  }

  void push(String remoteName, String branch) async{
    ProcessResult result = await Process.run(
      'git',
      ['push', remoteName, branch],
      workingDirectory: baseDirectory.path,
    );
    if (result.exitCode != 0) {
      print('git push stdout: ${result.stdout}');
      print('git push stderr: ${result.stderr}');
      throw Exception('Failed executing git push $remoteName $branch\nstderr:\n${result.stderr}');
    }
  }

  @override
  String toString() {
    return 'GitClone{baseDirectory: $baseDirectory}';
  }
}