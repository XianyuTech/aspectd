import 'dart:io';

import "package:path/path.dart" as p;
import 'package:yaml/yaml.dart';

RegExp pluginNameExp = new RegExp(r"^[a-zA-Z_][a-zA-Z0-9_]*$",);

/// This function is used to generate plugins based on configurations specified
/// in lib/src/plugins/config.yaml.
int main(List<String> args) {
  final Directory curDir = Directory(Platform.script.toFilePath());
  final String pluginsFolder = p.join(curDir.parent.parent.path, 'lib', 'src', 'plugins');
  final String configYamlPath = p.join(curDir.parent.parent.path, 'config.yaml');
  final File configYamlFile = File(configYamlPath);
  List<String> pluginsList = [];
  if (configYamlFile.existsSync()) {
    final dynamic pubspec = loadYaml(configYamlFile.readAsStringSync());
    if (pubspec == null)
      return null;
    final YamlList pluginsNode = pubspec['plugins'];
    for(YamlNode yamlNode in pluginsNode.nodes) {
      if (yamlNode.value == null)
        continue;
      String pluginName = yamlNode.value.toString();
      if (!pluginNameExp.hasMatch(pluginName))
        continue;
      pluginsList.add(pluginName);
    }
  }

  bool needRegenerate = false;
  final int pluginCnt = pluginsList.length;
  for (int i=0; i<pluginCnt; i++) {
    final bool itemRegenerate = checkIfGeneratePlugin(pluginsFolder, pluginsList[i]);
    needRegenerate = needRegenerate || itemRegenerate;
  }

  if (needRegenerate) {
    // Generate aspectd.dart as an export file
    String aspectdContent = '';
    for (int i = 0; i < pluginCnt; i++) {
      final String pluginItem = pluginsList[i];
      aspectdContent =
      '${aspectdContent}export \'package:aspectd/src/plugins/${pluginItem}/${pluginItem}.dart\';\n';
    }

    // Generate transformer_wrapper.dart as an export file
    String transformerWrapperImport = '';
    String transformerWrapperCallTransform = '';
    for (int i = 0; i < pluginCnt; i++) {
      final String pluginItem = pluginsList[i];
      final String firstUpPluginItem = pluginItem[0].toUpperCase()+(pluginItem.length==1?'':pluginItem.substring(1));
      transformerWrapperImport =
      '${transformerWrapperImport}import \'package:aspectd/src/plugins/${pluginItem}/${pluginItem}_transformer_wrapper.dart\';\n';
      transformerWrapperCallTransform =
      '${transformerWrapperCallTransform}${firstUpPluginItem}WrapperTransformer ${pluginItem}WrapperTransformer = new ${firstUpPluginItem}WrapperTransformer(platformStrongComponent: this.platformStrongComponent);\n    ${pluginItem}WrapperTransformer.transform(component);\n\n    ';
    }
    String transformerWrapperContent = '''
import 'package:kernel/ast.dart';
${transformerWrapperImport}
class TransformerWrapper{
  Component platformStrongComponent;
  
  TransformerWrapper(this.platformStrongComponent);
  
  bool transform(Component component){
    ${transformerWrapperCallTransform}return true;
  }
}''';
    final File aspectdFile = File(p.join(Directory(pluginsFolder).parent.parent.path, 'aspectd.dart'));
    if (!aspectdFile.existsSync()) {
      aspectdFile.createSync();
    }
    aspectdFile.writeAsStringSync(aspectdContent);

    final File transformerWrapperFile = File(p.join(Directory(pluginsFolder).parent.parent.path, 'transformer_wrapper.dart'));
    if (!transformerWrapperFile.existsSync()) {
      transformerWrapperFile.createSync();
    }
    transformerWrapperFile.writeAsStringSync(transformerWrapperContent);
  }
  return 0;
}

/// This function will check if a plugin is necessary to generate, if needed,
/// corresponding folders, files will be created.
/// When needed to generate a plugin, return true, false otherwise.
bool checkIfGeneratePlugin(String pluginsDir, String pluginName) {
  final String firstUpPluginItem = pluginName[0].toUpperCase()+(pluginName.length==1?'':pluginName.substring(1));
  final String pluginFolder = p.join(pluginsDir, pluginName);
  final File pluginExportFile = File(p.join(pluginFolder, '${pluginName}.dart'));
  final File pluginTransformerFile = File(p.join(pluginFolder, '${pluginName}_transformer_wrapper.dart'));
  if (pluginExportFile.existsSync() || pluginTransformerFile.existsSync()) {
    return false;
  }
  if (!Directory(pluginFolder).existsSync()) {
    Directory(pluginFolder).createSync();
  }
  pluginExportFile.createSync();
  pluginTransformerFile.createSync();

  // We don't generate content for export file as it's unknown.
  // Generate content for transformer as it has a pattern.
  final String pluginTransformerTemplate = '''
import 'package:kernel/ast.dart';

class ${firstUpPluginItem}WrapperTransformer {
  Component platformStrongComponent;

  ${firstUpPluginItem}WrapperTransformer({this.platformStrongComponent});

  void transform(Component program) {
  
  }
}
''';
  pluginTransformerFile.writeAsStringSync(pluginTransformerTemplate, flush: true);
  return true;
}