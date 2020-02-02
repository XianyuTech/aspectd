import 'package:args/args.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/kernel.dart';

import '../transformer/transformer_wrapper.dart';
import '../util/dill_ops.dart';

const String _kOptionInput = 'input';
const String _kOptionOutput = 'output';
const String _kOptionSdkRoot = 'sdk-root';
const String _kOptionMode = 'mode';
Map<String, Library> libraryAbbrMap = <String, Library>{};

int main(List<String> args) {
  final ArgParser parser = ArgParser()
    ..addOption(_kOptionInput, help: 'Input dill file')
    ..addOption(_kOptionOutput, help: 'Output dill file')
    ..addOption(_kOptionSdkRoot, help: 'Sdk root path')
    ..addOption(_kOptionMode, help: 'Transformer mode, flutter as default');
  final ArgResults argResults = parser.parse(args);
  final String intputDill = argResults[_kOptionInput];
  final String outputDill = argResults[_kOptionOutput];
  final String sdkRoot = argResults[_kOptionSdkRoot];
  final String transformerMode = argResults[_kOptionMode] ?? 'flutter';

  final DillOps dillOps = DillOps();
  final Component component = dillOps.readComponentFromDill(intputDill);
  Component platformStrongComponent;
  if (sdkRoot != null) {
    platformStrongComponent =
        dillOps.readComponentFromDill(sdkRoot + 'platform_strong.dill');
    for (Library library in platformStrongComponent.libraries) {
      libraryAbbrMap.putIfAbsent(library.name, () => library.reference.node);
    }
  }

  if (transformerMode == 'dart') {
    completeDartComponent(component);
  }

  for (CanonicalName canonicalName in component.root.children) {
    Library library = libraryAbbrMap[canonicalName.name];
    library ??= libraryAbbrMap[canonicalName.name.replaceAll(':', '.')];
    if (canonicalName.reference == null) {
      canonicalName.reference = Reference()..node = library;
    } else if (canonicalName.reference.canonicalName != null &&
        canonicalName.reference.node == null) {
      canonicalName.reference.node = library;
    }
  }

  final TransformerWrapper transformerWrapper =
      TransformerWrapper(platformStrongComponent);
  transformerWrapper.transform(component);

  dillOps.writeDillFile(component, outputDill);
  return 0;
}

void completeDartComponent(Component component) {
  final Map<String, Library> componentLibraryMap = <String, Library>{};
  for (Library library in component.libraries) {
    componentLibraryMap.putIfAbsent(
        library.importUri.toString(), () => library);
  }
  for (CanonicalName canonicalName
      in List<CanonicalName>.from(component.root.children.toList())) {
    if (!componentLibraryMap.containsKey(canonicalName.name)) {
      Library library = libraryAbbrMap[canonicalName.name];
      library ??= libraryAbbrMap[canonicalName.name.replaceAll(':', '.')];
      component.root.removeChild(canonicalName.name);
      component.libraries.add(library);
    }
  }
  component.adoptChildren();
}
