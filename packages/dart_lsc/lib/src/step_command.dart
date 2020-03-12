import 'dart:async';
import 'dart:io' show Process, ProcessResult, stderr;
import 'dart:math' show max;

import 'package:dart_lsc/src/git_repository.dart';
import 'package:dart_lsc/src/pub_package.dart';
import 'package:dart_lsc/src/version_bump.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import 'base_command.dart';
import 'github.dart';

FileSystem fs = LocalFileSystem();

class StepCommand extends BaseLscCommand {

  StepCommand() {
    argParser.addOption(
        requiredOption('project'),
        help: 'Required. The project number for the LSC tracking project (this is generated by dart_lsc initialize).');
    argParser.addOption(
        requiredOption('update_script'),
        help: 'Required. The command to execute to apply the LSC to the package.');
    argParser.addMultiOption(
        'update_script_args',
        help: 'Optional. Additional arguments to pass to the update script.');
    argParser.addOption(
        'update_script_options',
        help: 'Optional. Additional options to pass to the update script.');
    argParser.addOption(
        requiredOption('title'),
        help: 'Required. The title for this migration (used in commit message and changelog entries). Don\'t end the sentence with a period.');
    argParser.addOption(
        requiredOption('pr_body'),
        help: 'Required. The body of migration PRs sent by the tool.');
    argParser.addFlag('dry_run', help: 'Stage changes locally without updating GitHub');
  }

  @override
  String get description => 'Steps through an LSC';

  @override
  String get name => 'step';


  GitHubClient _gitHubClient;
  String _owner;
  String _updateScript;
  List<String> _updateScriptArgs;
  String _updateScriptOptions;
  List<String> _dependentPackagesOf;
  String _title;
  String _prBody;
  bool _dryRun;

  @override
  FutureOr<int> run() async {
    if (!verifyCommandLineOptions()) {
      return 1;
    }

    _dependentPackagesOf = argResults['dependent_packages_of'];
    final String token = argResults['github_auth_token'];
    _owner = argResults['tracking_repository_owner'];
    final String repositoryName = argResults['tracking_repository'];
    final String projectNumber = argResults['project'];
    _updateScript = argResults['update_script'];
    _updateScriptArgs = argResults['update_script_args'];
    _updateScriptOptions = argResults['update_script_options'];
    _title = argResults['title'];
    _prBody = argResults['pr_body'];
    _dryRun = argResults['dry_run'];

    _gitHubClient = GitHubClient(token);

    final String errorMsg = await _gitHubClient.verifyAuthentication();
    if (errorMsg != null) {
      stderr.write("$errorMsg\n");
      return 1;
    }

    final GitHubRepository repository = await _gitHubClient.getRepository(_owner, repositoryName);
    final GitHubProject project = await repository.getLscProject(projectNumber);

    List<GitHubIssue> todoIssues = await project.getColumnIssues('TODO');
    List<GitHubIssue> prSentIssues = await project.getColumnIssues('PR Sent');
    List<GitHubIssue> prMergedIssues = await project.getColumnIssues('PR Merged');
    List<GitHubIssue> manualInterventionIssues = await project.getColumnIssues('Need Manual Intervention');

    if (_dryRun) {
      print('Executing a dry run');
    }
    await handleTodo(todoIssues);
    if (!_dryRun) {
      await handlePrSent(prSentIssues);
      await handlePrMerged(prMergedIssues);
      await handleNeedManualIntervention(manualInterventionIssues);
    }
  }

  Future<List<GitHubIssue>> closeIfMigrated(List<GitHubIssue> issues, String targetColumnName, {bool inManualIntervention = false}) async {
    Directory baseDir = await fs.systemTempDirectory.createTemp('lsc');
    print('Downloading packages to ${baseDir.path}');
    int i = 0;
    final List<GitHubIssue> nonMigratedIssues = [];
    for (GitHubIssue issue in issues) {
      i++;
      PubPackage package = PubPackage(issue.package);
      print ('Fetching package $i of ${issues.length} (${package.name})');
      Directory packageDir = await package.fetchLatest(baseDir);

      bool updateNeeded = false;
      StringBuffer errorMessage = StringBuffer();
      bool hadError = false;
      for (String dependency in _dependentPackagesOf) {
        final List<String> args = [];
        args.addAll(_updateScriptArgs);
        args.addAll(['is_change_needed', '${dependency}', '--script_args=$_updateScriptOptions']);
        final ProcessResult result = await Process.run(
          _updateScript,
          args,
          workingDirectory: packageDir.path,
        );
        if (result.exitCode == 2) {
          updateNeeded = true;
          continue;
        }
        if (result.exitCode != 0) {
          hadError = true;
          errorMessage.write('Executed is_change_needed script with options: `$_updateScriptOptions`\n\n');
          errorMessage.write('stdout:\n```\n');
          errorMessage.write(result.stdout);
          errorMessage.write('\n```\n\n');
          errorMessage.write('stderr:\n```\n');
          errorMessage.write(result.stderr);
          errorMessage.write('\n```\n\n');
        }
      }

      if (hadError) {
        print('errors running is_change_needed:\n${errorMessage.toString()}');
        if (!inManualIntervention) {
          final String msg = 'Manual intervention is needed\n\n${errorMessage.toString()}';
          await issue.markManualIntervention(msg, dryRun: _dryRun);
        }
      } else if (updateNeeded) {
        nonMigratedIssues.add(issue);
        continue;
      } else {
        final String msg = 'Further migration is not needed.\n';
        if (_dryRun) {
          print('[dry_run] Further migration is not needed for ${issue.package}');
          continue;
        }
        await issue.moveToProjectColumn(targetColumnName);
        await issue.addComment(msg);
        await issue.closeIssue();

        final Map<String, dynamic> metadata = issue.getMetadata();
        if (metadata.containsKey('pr')) {
          final Uri prUri = Uri.parse(metadata['pr']);
          final String repository = prUri.pathSegments[1];

          print('Deleting repository $_owner/$repository');
          await _gitHubClient.deleteRepository(_owner, repository);
        }
      }
    }
    baseDir.delete(recursive: true);
    return nonMigratedIssues;
  }

  void handleTodo(List<GitHubIssue> issues) async {
    Directory baseDir = await fs.systemTempDirectory.createTemp('lsc');
    issues = await closeIfMigrated(issues, 'No Need To Migrate');
    print('Creating git clones at ${baseDir.path}');
    for (GitHubIssue issue in issues) {
      PubPackage pubPackage = PubPackage(issue.package);
      String homepage = await pubPackage.fetchHomepageUrl();
      GitHubGitRepository repository = GitHubGitRepository.fromUrl(homepage);
      if (repository == null) {
        issue.markManualIntervention(
          "dart_lsc can't detect a git repository base on url: $homepage",
          dryRun: _dryRun,
        );
        continue;
      }
      print('cloning $repository');
      GitClone clone;
      try {
        clone = await repository.clone(baseDir);
      } catch (e) {
        issue.markManualIntervention("dart_lsc failed cloning\n```\n$e\n```", dryRun: _dryRun);
        continue;
      }
      if (!clone.pubspec.existsSync()) {
        issue.markManualIntervention(
          "dart_lsc can't find the package's pubspec on git",
          dryRun: _dryRun,
        );
        continue;
      }

      bool hadError = false;
      StringBuffer errorMessage = StringBuffer();
      int versionBump = 10;
      for (String dependency in _dependentPackagesOf) {
        final List<String> args = [];
        args.addAll(_updateScriptArgs);
        args.addAll([
          'migrate',
          '${dependency}',
          '--script_args=$_updateScriptOptions'
        ]);
        final ProcessResult result = await Process.run(
          _updateScript,
          args,
          workingDirectory: clone.packageDirectory.path,
        );

        if (result.exitCode == 1) {
          hadError = true;
          errorMessage.write(
              'Executed migrate script with options: `$_updateScriptOptions`\n\n');
          errorMessage.write('stdout:\n```\n');
          errorMessage.write(result.stdout);
          errorMessage.write('\n```\n\n');
          errorMessage.write('stderr:\n```\n');
          errorMessage.write(result.stderr);
          errorMessage.write('\n```\n\n');
        }

        versionBump = max(versionBump, result.exitCode);
      }
      // if failed move to manual intervention
      if (hadError) {
        print('errors running is_change_needed:\n${errorMessage.toString()}');
        final String msg = 'Manual intervention is needed\n\n${errorMessage
            .toString()}';
        await issue.markManualIntervention(msg, dryRun: _dryRun);
        continue;
      }
      String error;

      error = await bumpVersion(
          clone.packageDirectory,
          versionBump,
          '* $_title. ([dart_lsc](http://github.com/amirh/dart_lsc))'
      );
      if (error != null) {
        print('failed bumping version:\b$error');
        final String msg = 'Manual intervention is needed\n\n$error';
        await issue.markManualIntervention(msg);
        continue;
      }

      String changeTitle = '[dart_lsc] $_title';
      error = await clone.addAndCommit(changeTitle);
      if (error != null) {
        print('$error');
        final String msg = 'Manual intervention is needed\n\n$error';
        await issue.markManualIntervention(msg, dryRun: _dryRun);
        continue;
      }

      if (_dryRun) {
        print('[dry_run] Staging change from ${clone.packageDirectory.path}');
        continue;
      }

      try {

        GitHubRepository gitHubRepository = await _gitHubClient.getRepository(
            repository.owner, repository.repository);

        Set<String> forks = await gitHubRepository.getForks();
        if (forks.contains('$_owner/${repository.repository}')) {
          issue.markManualIntervention('The $_owner/${repository.repository} fork already exists');
          continue;
        }
        print ('forking ${repository.owner}/${repository.repository} on GitHub');
        await _gitHubClient.forkRepository(repository.owner, repository.repository);
        await clone.addRemote(
            'staging',
            'git@github.com:${_owner}/${repository.repository}.git'
        );
        print ('staging change');
        await clone.push('staging', 'master');
        String prUrl = await gitHubRepository.sendPullRequest(
            targetBranch: 'master',
            sendingOwner: _owner,
            headBranch: 'master',
            title: changeTitle,
            body: _prBody);

        final Map<String, dynamic> issueMetadata = issue.getMetadata();
        issueMetadata['pr'] = prUrl;
        issue.setMetadata(issueMetadata);
        issue.moveToProjectColumn('PR Sent');
        issue.addComment('Sent migration PR: $prUrl');
      } catch (e) {
        print('$e');
        final String msg = 'Manual intervention is needed\n\n```\n$e\n```';
        await issue.markManualIntervention(msg);
        continue;
      }

    }
  }

    void handlePrSent(List<GitHubIssue> issues) async {
    issues = await closeIfMigrated(issues, 'Migrated');
    for (GitHubIssue issue in issues) {
      try {
        final Map<String, dynamic> metadata = issue.getMetadata();
        final Uri prUri = Uri.parse(metadata['pr']);
        final String owner = prUri.pathSegments[0];
        final String repository = prUri.pathSegments[1];
        final String number = prUri.pathSegments[3];

        GitHubPullRequest pullRequest = await _gitHubClient.getPullRequest(
            owner, repository, number);
        if (pullRequest.merged) {
          await issue.moveToProjectColumn('PR Merged');
          continue;
        }
        if (pullRequest.closed) {
          await issue.markManualIntervention('PR was closed without merging');
          continue;
        }
        if (pullRequest.commentsCount > 0) {
          await issue.markManualIntervention('PR have comments');
          continue;
        }
      } catch (e) {
        issue.markManualIntervention(e.toString());
      }
    }
  }

  void handlePrMerged(List<GitHubIssue> issues) async {
    issues = await closeIfMigrated(issues, 'Migrated');
  }

  void handleNeedManualIntervention(List<GitHubIssue> issues) async {
    issues = await closeIfMigrated(issues, 'Migrated', inManualIntervention: true);
  }
}
