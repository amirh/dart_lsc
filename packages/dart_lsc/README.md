# Dart LSC (Large Scale Change) Tool

[![Build Status](https://travis-ci.org/amirh/dart_lsc.svg?branch=master)](https://travis-ci.org/amirh/dart_lsc)

A tool for shepherding changes through the Dart ecosystem.

## Usage

Each LSC starts with a piece of code that can modify a given package. This piece of code is the `Migration`.
A `Migration` has a fairly simple interface, with just 2 core methods, one method determines if a package needs to be
changed, and the other applies the change to a single package.

```dart
abstract class Migration {
  Future<IsChangeNeededResult> isChangeNeeded(Directory packageDir, String dependencyName, String options);

  Future<MigrationResult> migrate(Directory packageDir, String dependencyName, String options);
}
```

An example `Migration` is [MigrateTo1](https://github.com/amirh/dart_lsc/blob/master/packages/migrate_to_1/lib/src/migrate_to_1.dart)
which implements a common migration: When package `foo` is ready to bump it's version from `0.1.2` to `1.0.0` `MigrateTo1`
updates packages that depend on `foo` to set a friendly version constraint of `foo: ">0.1.2 <=2.0.0"`. Some more details
on [why this is useful to do](https://github.com/flutter/flutter/wiki/Package-migration-to-1.0.0).

### Get a GitHub command line auth token
The `dart_lsc` tool tracks the migration status on GitHub and sends PRs on your behalf. To grant the tool the
permission to act on your behalf we need to provide it with a GitHub auth token, to generate a token follow the steps in
["Creating a personal access token for the command line"](https://help.github.com/articles/creating-an-access-token-for-command-line-use/).

For the example we'll assume that the `GITHUB_TOKEN` environment variable is set with the token.

### Initialize the migration
We initialize a migration with the following command:
```shell script
dart_lsc\
  initialize\
  --dependent_packages_of=foo\
  --github_auth_token=${GITHUB_TOKEN}\
  --tracking_repository_owner=<owner>\
  --tracking_repository=<tracking_repository>\
  --title="Prepare for foo 1.0.0"
```

The `dart_lsc` tool will:
 1. Query pub.dev for all the packages that depend on package foo.
 1. Create a new project in the <tracking_repository>.
 1. File a tracking issue in the <tracking_repository> for each package that depend on foo.
 
 When the project is initialized `dart_lsc` prints:
 
```
LSC project has been succesfully initialized!
Project URL: https://github.com/<owner>/<tracking_repository>/projects/1
```

This is what the initialized project looked like when I created an LSC for the `battery` plugin:

![](https://raw.githubusercontent.com/amirh/dart_lsc/master/docs/images/battery_project_initialized.png)

### The LSC project
LSC are tracked in a GitHub project, with columns that represent what each package is waiting for.
The `dart_lsc` tool automates the entirety of the migration for each package, when something unexpected happens
the issue is moved to the "Need Manual Intervention" column, issues in this column are the only ones that require
human attention.

### The update_script
The `Migration` code mentioned above needs is wrapped by a command line tool that follows a specific protocol. 
We refer to this tool as the `update_script` and the one we have for `MigrateTo1` is called `migrate_to_1`.

### Stepping through the LSC
The `dart_lsc` tool provides a `step` command, which goes over all the issues filed during migration initialization
when possible pushes the migration through one more step (e.g by sending a PR or marking a package as migrated).

This `step` command should be executed periodically until the migration is complete.

```shell script
dart_lsc step\
 --tracking_repository_owner=<tracking_repository_owner>\
 --tracking_repository=<tracking_repository>\
 --project=1\
  --github_auth_token=${GITHUB_TOKEN}\
 --dependent_packages_of=foo\
 --update_script="migrate_to_1"\
 --update_script_options={\"foo\":\"0.1.2\"}\
 --title="Adjust foo's version constraints to accept the 1.0.0 version [dart_lsc]"\
 --pr_body="This should be a safe change, for more details see: https://github.com/flutter/flutter/wiki/Package-migration-to-1.0.0\n\nThis change was auto generated by [dart_lsc](https://github.com/amirh/dart_lsc/tree/master/packages/dart_lsc)."
```


The `dart_lsc` tool will send PRs and update issues on your behalf. When PRs are merged or commented on the tool
updates their issues appropriately. Run this command in a day or two to keep moving this migration forward.

Remember that `dart_lsc` automates most of the workflow, if something required human attention it will be moved to the
"Needs Manual Intervention" column that's where you should be looking after running a step.

### Record your LSC
If you're using `dart_lsc` for a migration please list your migration in this [tracking document](https://github.com/amirh/dart_lsc/blob/master/LSC_LIST.md).
