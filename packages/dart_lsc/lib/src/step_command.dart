import 'dart:async';

import 'base_command.dart';

class StepCommand extends BaseLscCommand {

  StepCommand() {
    argParser.addOption(
        requiredOption('update_script'),
        help: 'Required. The command to execute to apply the LSC to the package.');

    argParser.addOption(
        ('update_script_args'),
        help: 'Optional. Additional arguments to pass to the update script.');
  }

  @override
  String get description => 'Steps through an LSC';

  @override
  String get name => 'step';

  @override
  FutureOr<int> run() async {
    if (!verifyCommandLineOptions()) {
      return 1;
    }
  }
}
