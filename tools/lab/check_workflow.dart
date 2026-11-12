import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final workflow = loadYaml(File('.github/workflows/functional-arm64-lab.yml').readAsStringSync()) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  if (jobs['build']['if'] != "github.event_name == 'workflow_dispatch'") {
    throw StateError('Build must require manual dispatch');
  }
  final directory = Directory('build/qa/workflow-syntax')..createSync(recursive: true);
  var index = 0;
  for (final job in jobs.values) {
    for (final step in job['steps']) {
      if (step['run'] is String) {
        File('${directory.path}/${index++}.sh').writeAsStringSync(step['run'] as String);
      }
    }
  }
  stdout.writeln('Workflow YAML valid; $index shell blocks extracted for bash -n');
}
