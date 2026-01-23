import 'dart:io';
import 'package:args/args.dart';
import '../utils/string_utils.dart';
import '../utils/logger.dart';

class CreateCommand {
  Future<void> execute(List<String> args) async {
    final createParser = _buildArgParser();
    final mainParser = _buildMainParser(createParser);

    try {
      final results = mainParser.parse(args);

      if (results['help']) {
        if (results.command != null && results.command!.name == 'create') {
          _printCreateHelp(createParser);
          exit(0);
        } else {
          _printHelp(mainParser);
          exit(0);
        }
      }

      if (results.command != null) {
        if (results.command!.name == 'create' &&
            results.command!['page'] != null) {
          await _createPage(results.command!['page']);
          exit(0);
        } else if (results.command!.arguments.isEmpty) {
          await _createDefaultArchitectureFolders();
          exit(0);
        } else {
          CliLogger.error('Missing or invalid arguments.');
          _printHelp(mainParser);
          exit(2);
        }
      } else {
        CliLogger.error('Missing or invalid arguments.');
        _printHelp(mainParser);
        exit(2);
      }
    } catch (e) {
      if (e is FormatException) {
        CliLogger.error('Invalid command format: ${e.message}');
      } else if (e is FileSystemException) {
        CliLogger.error('File system error: ${e.message}');
      } else if (e is ArgumentError) {
        CliLogger.error('Invalid argument: ${e.message}');
      } else {
        CliLogger.error('Unexpected error: ${e.toString()}');
      }
      _printHelp(mainParser);
      exit(2);
    }
  }

  ArgParser _buildMainParser(ArgParser createParser) {
    final parser = ArgParser();
    parser.addCommand('create', createParser);
    parser.addFlag('help',
        abbr: 'h', help: 'Show this message and exit.', negatable: false);
    return parser;
  }

  ArgParser _buildArgParser() {
    final create = ArgParser();
    create.addOption('page', abbr: 'p', help: 'Creates page with given value.');
    create.addFlag('help',
        abbr: 'h', help: 'Show this message and exit.', negatable: false);
    return create;
  }

  Future<void> _createDefaultArchitectureFolders() async {
    CliLogger.info('Creating Architecture Folders...');
    var dir = '${Directory.current.path}/lib/src/';

    try {
      await Future.wait([
        Directory('${dir}app/pages').create(recursive: true),
        Directory('${dir}app/widgets').create(recursive: true),
        Directory('${dir}app/utils').create(recursive: true),
        File('${dir}app/navigator.dart').create(recursive: true),
        Directory('${dir}data/repositories').create(recursive: true),
        Directory('${dir}data/helpers').create(recursive: true),
        File('${dir}data/constants.dart').create(recursive: true),
        Directory('${dir}device/repositories').create(recursive: true),
        Directory('${dir}device/utils').create(recursive: true),
        Directory('${dir}domain/entities').create(recursive: true),
        Directory('${dir}domain/usecases').create(recursive: true),
        Directory('${dir}domain/repositories').create(recursive: true),
      ]);

      CliLogger.success('Architecture folders created successfully!');
    } catch (e) {
      CliLogger.error('Failed to create architecture folders: $e');
      rethrow;
    }
  }

  Future<void> _createPage(String name) async {
    if (!_isValidPageName(name)) {
      CliLogger.error(
          'Invalid page name "$name". Use snake_case format (e.g., "user_profile")');
      exit(1);
    }

    if (await _pageExists(name)) {
      CliLogger.error('Page "$name" already exists.');
      exit(1);
    }

    CliLogger.info('Creating page: $name');
    final dir = '${Directory.current.path}/lib/src/app/pages/$name/$name';

    try {
      await Future.wait([
        _createFile('${dir}_presenter.dart', _presenterContent(name)),
        _createFile('${dir}_controller.dart', _controllerContent(name)),
        _createFile('${dir}_view.dart', _viewContent(name)),
      ]);

      CliLogger.success('Page "$name" created successfully!');
    } catch (e) {
      CliLogger.error('Error creating page: $e');
      rethrow;
    }
  }

  String _viewContent(String name) {
    var pascalCaseName = StringUtils.convertToPascalCase(name);

    return '''
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

import '${name}_controller.dart';

class ${pascalCaseName}View extends CleanView {
  const ${pascalCaseName}View({super.key});

  @override
  State<StatefulWidget> createState() {
    return _${pascalCaseName}ViewState(
      ${pascalCaseName}Controller(),
    );
  }
}

class _${pascalCaseName}ViewState extends CleanViewState<${pascalCaseName}View, ${pascalCaseName}Controller> {
  _${pascalCaseName}ViewState(${pascalCaseName}Controller controller) : super(controller);

  @override
  Widget get view {
    return const Placeholder();
  }
}
  ''';
  }

  String _controllerContent(String name) {
    var pascalCaseName = StringUtils.convertToPascalCase(name);
    return '''
import 'package:zuraffa/zuraffa.dart';

import '${name}_presenter.dart';

class ${pascalCaseName}Controller extends Controller {
  final ${pascalCaseName}Presenter _presenter;

  ${pascalCaseName}Controller() : _presenter = ${pascalCaseName}Presenter();

  @override
  void initListeners() {
    // TODO: Implement initListeners
  }
}
  ''';
  }

  String _presenterContent(String name) {
    var pascalCaseName = StringUtils.convertToPascalCase(name);
    return '''
import 'package:zuraffa/zuraffa.dart' as clean;

class ${pascalCaseName}Presenter extends clean.Presenter {
  @override
  void dispose() {
    // TODO: Implement dispose
  }
}
  ''';
  }

  Future<void> _createFile(String path, String content) async {
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(content);
    final fileName = path.split('/').last;
    CliLogger.info('Created $fileName');
  }

  bool _isValidPageName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*[a-z0-9]$').hasMatch(name);
  }

  Future<bool> _pageExists(String name) {
    final dir = Directory('${Directory.current.path}/lib/src/app/pages/$name');
    return dir.exists();
  }

  void _printHelp(ArgParser parser) {
    print('''
🚀 Zuraffa CLI

A command-line tool for generating Clean Architecture components in Flutter projects.

USAGE:
  ${parser.usage}

COMMANDS:
  generate    Generate architecture components (pages, entities, use cases)
  create      Create architecture folders and files

EXAMPLES:
  zfa create --page user_profile
  zfa create

For more information about a specific command, run:
  zfa <command> --help
''');
  }

  void _printCreateHelp(ArgParser parser) {
    print('''
🚀 Zuraffa CLI - Create Command

Creates architecture related folders and files.

USAGE:
  ${parser.usage}

OPTIONS:
  -p, --page <name>    Creates a page with the given name (snake_case format)

EXAMPLES:
  zfa create --page user_profile
  zfa create --page product_detail
  zfa create
''');
  }
}
