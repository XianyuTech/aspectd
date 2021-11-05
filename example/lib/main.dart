import 'dart:math';
import 'package:flutter/material.dart';
import 'package:example/custom_page.dart';
import 'package:example/custom_list.dart';
import 'package:flutter/services.dart';
import 'package:growingio_sdk_autotracker_plugin/growingio_sdk_autotracker_plugin.dart';
// import 'package:example/webview_page.dart';
import 'dart:ui' as ui show window;

void main() {
  C()..fa();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
      routes: <String, WidgetBuilder> {
        '/a': (BuildContext context) => CustomPage(title: 'page A'),
        '/b': (BuildContext context) => CustomList(title: 'page B'),
        // '/web': (BuildContext context) => WebViewExample(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key,  required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  static int getTag() => 1;
  static int getTag2() => 2;
  int getTag3() => 3;

  final String title;

  @override
  _MyHomePageState createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  // void onRandomDemo() {
  //   final Random random = Random();
  //   print('[KWLM]nextInt:${random.nextInt(100)}');
  //   print('[KWLM]nextDouble:${random.nextDouble()}');
  //   print('[KWLM]nextBool:${random.nextBool()}');
  // }

  void push(String route) {
    Navigator.of(context).pushNamed(route);
  }

  void _incrementCounter() {
    C()..fc();
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }
  static const platform = const MethodChannel('samples.flutter.dev/goToNativePage');

  Future<void> _goToNativePage() async {
    try {
      return await platform
          .invokeMethod('goToNativePage', {'test': 'from flutter'});
    } on PlatformException catch (e) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
            GestureDetector(
                child:
                const Text('Push Native VC', style: TextStyle(fontSize: 20)),
                onTap: () {
                  _goToNativePage();
                }),
            GestureDetector(
                child:
                const Text('Push Flutter/Native', style: TextStyle(fontSize: 20)),
                onTap: () {
                  push("/a");
                  // onRandomDemo();
                }),
            GestureDetector(
                child:
                const Text('CustomPage /a', style: TextStyle(fontSize: 20)),
                onTap: () {
                  push("/a");
                }),
            GestureDetector(
                child:
                const Text('CustomList /b', style: TextStyle(fontSize: 20)),
                onTap: () {
                  push("/b");
                }),
            GestureDetector(
                child:
                const Text('Start WebCircle Data', style: TextStyle(fontSize: 20)),
                onTap: () {
                  GrowingAutotracker.getInstance().webCircleRunning = true;
                  // MediaQueryData mediaQuery = MediaQueryData.fromWindow(ui.window);
                  // print("mediaQuery.devicePixelRatio is ${mediaQuery.devicePixelRatio}");
                })
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          _incrementCounter();
        },
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),

    );
  }
}

class A {
  void fa(){}
}

class B {
  void fb() {

  }
}

class C with A,B {
  C(){

  }
  void fc() {

  }
}