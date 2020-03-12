import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import 'global.dart';

class GitHubGitRepository {
  GitHubGitRepository(this.owner, this.repository, this.path);

  final String owner;
  final String repository;
  final String path;

  static GitHubGitRepository fromUrl(String url) {
    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch(FormatException) {
     return null;
    }

    if (uri.authority != 'github.com') {
      return null;
    }

    final String owner = uri.pathSegments[0];
    final String repository = uri.pathSegments[1];
    String prefix = '/$owner/$repository';
    if (uri.pathSegments.length > 3 && uri.pathSegments[2] == 'tree') {
      prefix = '$prefix/${uri.pathSegments[2]}/${uri.pathSegments[3]}/';
    };

    final String path = uri.path.substring(prefix.length);

    return GitHubGitRepository(owner, repository, path);
  }

  Future<GitClone> clone(Directory workingDirectory) async {
    String gitUri = 'git@github.com:$owner/$repository.git';
    final ProcessResult result = await Process.run(
        'git',
        ['clone', gitUri],
        workingDirectory: workingDirectory.path,
    );
    if (result.exitCode != 0) {
      throw Exception('git clone failed for $gitUri');
    }
    return GitClone(this, workingDirectory.childDirectory(repository));
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
  GitClone(this.repository, this.baseDirectory);

  final GitHubGitRepository repository;
  final Directory baseDirectory;

  Directory get packageDirectory {
    if (repository.path == null)
      return baseDirectory;
    return fs.directory(path.join(baseDirectory.path, repository.path));
  }

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
      return 'git add failed for ${repository.repository}';
    }

    result = await Process.run(
      'git',
      ['commit', '-m', msg],
      workingDirectory: baseDirectory.path,
    );
    if (result.exitCode != 0) {
      print('git commit stdout: ${result.stdout}');
      print('git commit stderr: ${result.stderr}');
      return 'git commit failed for ${repository.repository}';
    }
    return null;
  }

  @override
  String toString() {
    return 'GitClone{repository: $repository, baseDirectory: $baseDirectory}';
  }
}