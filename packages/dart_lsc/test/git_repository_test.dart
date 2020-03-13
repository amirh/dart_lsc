import 'package:dart_lsc/src/git_repository.dart';
import 'package:dart_lsc/src/pub_package.dart';
import 'package:test/test.dart';

void main() {

  test('non GitHub URL', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl(
      PubUrls(homepage: 'https://flutter.dev'),
    );
    expect(repository, null);
  });

  test('GitHub URLs', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl(PubUrls(
      homepage: 'https://github.com/flutter/plugins/tree/master/packages/battery',
    ));
    expect(repository, GitHubGitRepository('flutter', 'plugins', 'packages/battery'));
    repository = GitHubGitRepository.fromUrl(PubUrls(
      homepage: 'https://github.com/debuggerx01/battery_indicator',
    ));
    expect(repository, GitHubGitRepository('debuggerx01', 'battery_indicator', ''));
  });

  test('Not a GitHub Repo URL', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl(PubUrls(
      homepage: 'https://github.com/wiatec',
    ));
    expect(repository, null);
  });

  test('GitHub homepage with a valid repository', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl(PubUrls(
      homepage: 'https://github.com/wiatec',
      repository: 'https://github.com/wiatec/flutter_common',
    ));
    expect(repository, GitHubGitRepository('wiatec', 'flutter_common', ''));
  });

  test('www.github.com', () async {
    GitHubGitRepository repository = GitHubGitRepository.fromUrl(PubUrls(
      homepage: 'https://www.github.com/jamiewest/version_tracking',
    ));
    expect(repository, GitHubGitRepository('jamiewest', 'version_tracking', ''));
  });
}

