import 'dart:io';

import 'package:args/command_runner.dart';

abstract class BaseLscCommand extends Command<int> {
  BaseLscCommand() {
    argParser.addMultiOption(
        requiredMultiOption('dependent_packages_of'),
        help: 'Required. Comma separated of pub packages. The LSC will be executed on all pub packages with at least one dependency on this list'
    );
    argParser.addOption(
        requiredOption('github_auth_token'),
        help: 'Required. GitHub command line authorization token, for instructions on how to create a token see: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line');
    argParser.addOption(
        requiredOption('tracking_repository_owner'),
        help: 'Required. The owner of the repository in which the migration is going to be tracked (this is where issues are filed). E.g if you want to track this in amirh/migration pass --tracking_repository_owner=amirh.');
    argParser.addOption(
        requiredOption('tracking_repository'),
        help: 'Required. The repository in which the migration is going to be tracked (this is where issues are filed). E.g if you want to track this in amirh/migration pass --tracking_repository=migration.');
  }

  String requiredMultiOption(String option) {
    _requiredMultiOptions.add(option);
    return option;
  }

  String requiredOption(String option) {
    _requiredOptions.add(option);
    return option;
  }

  List<String> _requiredOptions = [];
  List<String> _requiredMultiOptions = [];

  bool verifyCommandLineOptions() {
    List<String> missingOptions = [];
    for (String name in _requiredMultiOptions) {
      final List<String> value = argResults[name];
      if (value.isEmpty) {
        missingOptions.add(name);
      }
    }

    for (String name in _requiredOptions) {
      if (argResults[name] == null) {
        missingOptions.add(name);
      }
    }

    if (missingOptions.isEmpty) {
      return true;
    }

    stderr.write('Missing required arguments: ${missingOptions.join(', ')}');
    return false;
  }
}
