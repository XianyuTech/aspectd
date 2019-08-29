import 'package:args/args.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/kernel.dart';
import 'dill_ops.dart';
import '../transformer/transformer_wrapper.dart';

const String _kOptionInput = 'input';
const String _kOptionOutput = 'output';
const String _kOptionSdkRoot = 'sdk-root';
Map<String,Library> libraryAbbrMap = Map<String, Library>();

int main(List<String> args) {
  print('args: ${args.toString()}');
  final ArgParser parser = ArgParser()
    ..addOption(_kOptionInput, help: 'Input dill file')..addOption(
        _kOptionOutput, help: 'Output dill file')..addOption(_kOptionSdkRoot, help: 'Sdk root path');
  final ArgResults argResults = parser.parse(args);
  final String intputDill = argResults[_kOptionInput];
  final String outputDill = argResults[_kOptionOutput];
  final String sdkRoot = argResults[_kOptionSdkRoot];

  DillOps dillOps = new DillOps();
  Component component = dillOps.readComponentFromDill(intputDill);
  Component platformStrongComponent = null;
  if(sdkRoot != null) {
    // /flutter/bin/cache/artifacts/engine/common/flutter_patched_sdk/platform_strong.dill
    platformStrongComponent = dillOps.readComponentFromDill(sdkRoot+'platform_strong.dill');
    for(Library library in platformStrongComponent.libraries){
      print('platform.library: ${library.name} = ${library.reference.node}');
      libraryAbbrMap.putIfAbsent(library.name, ()=>library.reference.node);
    }
  }

  for(CanonicalName canonicalName in component.root.children){
    print('app.dill: ${canonicalName.name}');
    Library library = libraryAbbrMap[canonicalName.name];
    library ??= libraryAbbrMap[canonicalName.name.replaceAll(':', '.')];
    if(canonicalName.reference == null) {
      canonicalName.reference = Reference()..node = library;
    }
    else if(canonicalName.reference.canonicalName != null && canonicalName.reference.node==null) {
      canonicalName.reference.node = library;
    }
  }

  TransformerWrapper transformerWrapper = new TransformerWrapper(platformStrongComponent);
  transformerWrapper.transform(component);

  dillOps.writeDillFile(component, outputDill);
  return 0;
}
