import 'dart:io';

import 'package:dart_lsc/executable.dart' as executable;

void main(List<String> arguments) async {
  int retval = await executable.main(arguments);
  if (retval != null) {
    exit(retval);
  }
}
