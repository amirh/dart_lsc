import 'dart:async';

import 'package:migrate_base/migrate_base.dart';

/// Run the command [runner] with the given [args] and return
/// what was printed.
Future<List<String>> runCapturingPrint(
    MigrationRunner runner, List<String> args) async {
  final List<String> prints = <String>[];
  final ZoneSpecification spec = ZoneSpecification(
    print: (_, __, ___, String message) {
      prints.add(message);
    },
  );
  await Zone.current
      .fork(specification: spec)
      .run<Future<void>>(() => runner.run(args));

  return prints;
}