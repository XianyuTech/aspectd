import 'dart:io';
import 'package:kernel/ast.dart';
import 'package:kernel/binary/ast_from_binary.dart';
import 'package:kernel/binary/ast_to_binary.dart';
import 'package:kernel/binary/limited_ast_to_binary.dart';

import 'package:kernel/kernel.dart' show Component;
import 'package:kernel/binary/ast_from_binary.dart'
    show BinaryBuilderWithMetadata;

class BinaryPrinterFactory {
  /// Creates new [BinaryPrinter] to write to [targetSink].
  BinaryPrinter newBinaryPrinter(Sink<List<int>> targetSink) {
    return new LimitedBinaryPrinter(targetSink, (_) => true /* predicate */,
        false /* excludeUriToSource */);
  }
}

class DillOps {
  DillOps() {
    printerFactory = new BinaryPrinterFactory();
  }
  BinaryPrinterFactory printerFactory;
  Component readComponentFromDill(String dillFile) {
    final Component component = new Component();
    final List<int> bytes = new File(dillFile).readAsBytesSync();

    new BinaryBuilderWithMetadata(bytes).readComponent(component);
    return component;
  }

  writeDillFile(Component component, String filename,
      {bool filterExternal: false}) async {
    final IOSink sink = new File(filename).openWrite();
    final BinaryPrinter printer = filterExternal
        ? new LimitedBinaryPrinter(
        sink, (lib) => !lib.isExternal, true /* excludeUriToSource */)
        : printerFactory.newBinaryPrinter(sink);

    component.libraries.sort((Library l1, Library l2) {
      return "${l1.fileUri}".compareTo("${l2.fileUri}");
    });

    component.computeCanonicalNames();
    for (Library library in component.libraries) {
      library.additionalExports.sort((Reference r1, Reference r2) {
        return "${r1.canonicalName}".compareTo("${r2.canonicalName}");
      });
    }

    printer.writeComponentFile(component);
    await sink.close();
  }
}