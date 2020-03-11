import 'dart:async';
import 'dart:io' show Process, ProcessResult;

import 'package:dart_lsc/src/git_repository.dart';
import 'package:dart_lsc/src/pub_package.dart';
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
        ('update_script_args'),
        help: 'Optional. Additional arguments to pass to the update script.');
    argParser.addOption(
        ('update_script_options'),
        help: 'Optional. Additional options to pass to the update script.');
  }

  @override
  String get description => 'Steps through an LSC';

  @override
  String get name => 'step';

  String _updateScript;
  List<String> _updateScriptArgs;
  String _updateScriptOptions;
  List<String> _dependentPackagesOf;

  @override
  FutureOr<int> run() async {
    if (!verifyCommandLineOptions()) {
      return 1;
    }

    _dependentPackagesOf = argResults['dependent_packages_of'];
    final String token = argResults['github_auth_token'];
    final String owner = argResults['tracking_repository_owner'];
    final String repositoryName = argResults['tracking_repository'];
    final String projectNumber = argResults['project'];
    _updateScript = argResults['update_script'];
    _updateScriptArgs = argResults['update_script_args'];
    _updateScriptOptions = argResults['update_script_options'];

    final GitHubClient gitHub = GitHubClient(token);
    final GitHubRepository repository = await gitHub.getRepository(owner, repositoryName);
    final GitHubProject project = await repository.getLscProject(projectNumber);

    List<GitHubIssue> todoIssues = await project.getColumnIssues('TODO');
    List<GitHubIssue> prSentIssues = await project.getColumnIssues('PR Sent');
    List<GitHubIssue> prMergedIssues = await project.getColumnIssues('PR Merged');
    List<GitHubIssue> manualInterventionIssues = await project.getColumnIssues('Need Manual Intervention');

    await handleTodo(todoIssues);
    await handlePrSent(prSentIssues);
    await handlePrMerged(prMergedIssues);
    await handleNeedManualIntervention(manualInterventionIssues);
  }

  Future<List<GitHubIssue>> closeIfMigrated(List<GitHubIssue> issues, String targetColumnName, {bool inManualIntervention = false}) async {
    Directory baseDir = await fs.systemTempDirectory.createTemp('lsc');
    print('Downloading packages to $baseDir ..');
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
          await issue.moveToProjectColumn('Need Manual Intervention');
          await issue.addComment(msg.toString());
        }
      } else if (updateNeeded) {
        nonMigratedIssues.add(issue);
        continue;
      } else {
        final String msg = 'Further migration is not needed.\n';
        await issue.moveToProjectColumn(targetColumnName);
        await issue.addComment(msg);
        await issue.closeIssue();
      }
    }
    baseDir.delete(recursive: true);
    return nonMigratedIssues;
  }

  void handleTodo(List<GitHubIssue> issues) async {
    Directory baseDir = await fs.systemTempDirectory.createTemp('lsc');
    issues = await closeIfMigrated(issues, 'No Need To Migrate');
    for (GitHubIssue issue in issues) {
      PubPackage pubPackage = PubPackage(issue.package);
      String homepage = await pubPackage.fetchHomepageUrl();
      GitHubGitRepository repository = GitHubGitRepository.fromUrl(homepage);
      if (repository == null) {
        issue.markManualIntervention("dart_lsc can't detect a git repository base on url: $homepage");
        continue;
      }
      print('cloning $repository');
      GitClone clone;
      try {
        clone = await repository.clone(baseDir);
      } catch(e) {
        issue.markManualIntervention("dart_lsc failed cloning\n```\n$e\n```");
        continue;
      }
      if (!clone.pubspec.existsSync()) {
        issue.markManualIntervention("dart_lsc can't find the package's pubspec on git");
        continue;
      }
      // if failed move to manual intervention
    }
  }

  void handlePrSent(List<GitHubIssue> issues) async {
    issues = await closeIfMigrated(issues, 'Migrated');
  }

  void handlePrMerged(List<GitHubIssue> issues) async {
    issues = await closeIfMigrated(issues, 'Migrated');
  }

  void handleNeedManualIntervention(List<GitHubIssue> issues) async {
    issues = await closeIfMigrated(issues, 'Migrated', inManualIntervention: true);
  }
}
