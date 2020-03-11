import 'dart:io';

import 'package:dart_lsc/executable.dart' as executable;

void main(List<String> arguments) async {
  exit(await executable.main(arguments));
}
