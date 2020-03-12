import 'dart:convert';

import 'package:dart_lsc/src/git_repository.dart';
import 'package:test/test.dart';

void main() {

  test('non GitHub URL', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl('https://flutter.dev');
    expect(repository, null);
  });

  test('GitHub URLs', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl('https://github.com/flutter/plugins/tree/master/packages/battery');
    expect(repository, GitHubGitRepository('flutter', 'plugins', 'packages/battery'));
    repository = GitHubGitRepository.fromUrl('https://github.com/debuggerx01/battery_indicator');
    expect(repository, GitHubGitRepository('debuggerx01', 'battery_indicator', ''));
  });
}
