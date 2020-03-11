import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:dart_lsc/src/initialize_command.dart';

Future<int> main(List<String> arguments) {
  final CommandRunner runner = CommandRunner<int>('dart_lsc', 'Shepherds a Large Scale Change through the Dart ecosystem')
    ..addCommand(InitializeCommand());
  return runner.run(arguments);
}

