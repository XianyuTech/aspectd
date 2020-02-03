import 'dart:io';
import 'package:path/path.dart' as p;

void copyDirectory(Directory source, Directory destination) =>
    source.listSync(recursive: false).forEach((FileSystemEntity entity) {
      if (entity is Directory) {
        final Directory newDirectory = Directory(
            p.join(destination.absolute.path, p.basename(entity.path)));
        newDirectory.createSync();

        copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        entity.copySync(p.join(destination.path, p.basename(entity.path)));
      }
    });
