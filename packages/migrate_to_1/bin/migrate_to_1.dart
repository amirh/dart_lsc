import 'dart:io';

import 'package:migrate_to_1/executable.dart' as executable;

Future<int> main(List<String> arguments) async {
  int retval = await executable.main(arguments);
  if (retval != null) {
    exit(retval);
  }
}
