import 'dart:async';

import 'package:dart_lsc/src/base_command.dart';
import 'package:dart_lsc/src/dependents_fetcher.dart';
import 'package:dart_lsc/src/github.dart';
import 'package:meta/meta.dart';

class InitializeCommand extends BaseLscCommand {

  InitializeCommand() {
    argParser.addOption(
        requiredOption('title'),
        help: 'Required. A short title for this migration, used in issue titles.');
  }

  @override
  String get description => 'Initialize an LSC';

  @override
  String get name => 'initialize';

  @override
  FutureOr<int> run() async {
    if(!verifyCommandLineOptions()) {
      return 1;
    }
    List<String> dependentPackagesOf = argResults['dependent_packages_of'];
    final String token = argResults['github_auth_token'];
    final String owner = argResults['tracking_repository_owner'];
    final String repositoryName = argResults['tracking_repository'];
    final String title = argResults['title'];

    final GitHubClient gitHub = GitHubClient(token);
    final GitHubRepository repository = await gitHub.getRepository(owner, repositoryName);
    final GitHubProject project = await repository.createLscProject(title);


    List<String> packagesToMigrate = [];
    for (String package in dependentPackagesOf) {
      DependentsFetcher fetcher = DependentsFetcher(package);
      while (await fetcher.fetchNextPage()) {}
      packagesToMigrate.addAll(fetcher.dependentPackages);
    }

    for (int i = 0; i < packagesToMigrate.length; i++) {
      final String package = packagesToMigrate[i];
      print('Creating issue ${i+1} / ${packagesToMigrate.length} ($package)');
      await project.createIssue(
          '[$package] $title',
          renderIssueBody(packageToMigrate: package)
      );
    }

    print('\nLSC project has been succesfully initialized!');
    print('Project URL: ${project.url}\n');
    print('To step through this LSC execute the following command:');
    print('dart_lsc step\\');
    print('  --tracking_repository_owner=$owner\\');
    print('  --tracking_repository=$repositoryName\\');
    print('  --project=${project.projectNumber}\\');
    print('  --github_auth_token=<token>\\');
    print('  --dependent_packages_of=${dependentPackagesOf.join(',')}\\');
    print('  --update_script=<update_script>\\');
    print('  [--update_script_args=<args>]');
    return 0;
  }
}

String renderIssueBody({@required String packageToMigrate}) {
  return '''This is part of a Large Scale Change managed by [dart_lsc](https://github.com/amirh/dart_lsc).

*Do not edit the title of this comment, it is auto-generated and contains information used by dart_lsc.*
 ''';
}