import 'dart:io';

import 'package:migrate_to_1/executable.dart' as executable;

void main(List<String> arguments) async {
  int retval = await executable.main(arguments);
  if (retval != null) {
    exit(retval);
  }
}
