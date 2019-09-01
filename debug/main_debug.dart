import '../tool/starter.dart' as starter;

void main() {
  List<String> args = [
    '--input',
    '/Users/bruce/flutter/flutter_open_project/dynamic/aspectd-fork/debug/app.dill',
    '--sdk-root',
    '/Users/bruce/flutter/flutter/bin/cache/artifacts/engine/common/flutter_patched_sdk/',
    '--output',
    '/Users/bruce/flutter/flutter_open_project/dynamic/aspectd-fork/debug/app.aspectd.dill',
  ];

  starter.main(args);
}
