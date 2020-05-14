import 'dart:io';
import 'package:kernel/ast.dart';
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/kernel.dart' show Component;
import 'package:kernel/binary/ast_from_binary.dart'
    show BinaryBuilderWithMetadata;
import 'package:vm/metadata/bytecode.dart' show BytecodeMetadataRepository;
import 'package:vm/metadata/direct_call.dart' show DirectCallMetadataRepository;
import 'package:vm/metadata/inferred_type.dart'
    show InferredTypeMetadataRepository;
import 'package:vm/metadata/procedure_attributes.dart'
    show ProcedureAttributesMetadataRepository;
import 'package:vm/metadata/table_selector.dart'
    show TableSelectorMetadataRepository;
import 'package:vm/metadata/unboxing_info.dart'
    show UnboxingInfoMetadataRepository;
import 'package:vm/metadata/unreachable.dart'
    show UnreachableNodeMetadataRepository;
import 'package:vm/metadata/call_site_attributes.dart'
    show CallSiteAttributesMetadataRepository;
import 'package:vm/metadata/binary_cache.dart'
    show BinaryCacheMetadataRepository;
import 'package:vm/metadata/obfuscation_prohibitions.dart'
    show ObfuscationProhibitionsMetadataRepository;

class DillOps {
  Component readComponentFromDill(String dillFile) {
    final component = new Component();

    // Register VM-specific metadata.
    component.addMetadataRepository(new DirectCallMetadataRepository());
    component.addMetadataRepository(new InferredTypeMetadataRepository());
    component.addMetadataRepository(new ProcedureAttributesMetadataRepository());
    component.addMetadataRepository(new TableSelectorMetadataRepository());
    component.addMetadataRepository(new UnboxingInfoMetadataRepository());
    component.addMetadataRepository(new UnreachableNodeMetadataRepository());
    component.addMetadataRepository(new BytecodeMetadataRepository());
    component.addMetadataRepository(new CallSiteAttributesMetadataRepository());

    final List<int> bytes = new File(dillFile).readAsBytesSync();
    new BinaryBuilderWithMetadata(bytes, disableLazyReading: true).readComponent(component);
    return component;
  }

  Future<void> writeDillFile(Component component, String filename,
      {bool filterExternal = false}) async {
    final IOSink sink = File(filename).openWrite();
    final BinaryPrinter printer = BinaryPrinter(sink);

    component.libraries.sort((Library l1, Library l2) {
      return '${l1.fileUri}'.compareTo('${l2.fileUri}');
    });

    component.computeCanonicalNames();
    for (Library library in component.libraries) {
      library.additionalExports.sort((Reference r1, Reference r2) {
        return '${r1.canonicalName}'.compareTo('${r2.canonicalName}');
      });
    }

    printer.writeComponentFile(component);
    await sink.close();
  }
}
