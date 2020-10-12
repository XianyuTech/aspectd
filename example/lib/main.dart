import 'dart:math';
import 'package:flutter/material.dart';

Future<void> appInit() async {}

Future<void> appInit2() async {}

class Observer {
  void onChanged(){

  }
}

void injectDemo(List<Observer> observers) {
  int a = 10;
  if (a > 5) {
    print('[KWLM]:if1');
  }
  print('[KWLM]:a');
  for (Observer o in observers) {
    print('[KWLM]:Observer1');
    o.onChanged();
    print('[KWLM]:Observer2');
  }
  print('[KWLM]:b');
  for (int i = 0; i < 10; i++) {
    print('[KWLM]:for i $i');
    print('[KWLM]:for i $i');
  }
  print('[KWLM]:c');
}

void main() {
  appInit();
  appInit2();
  injectDemo([]);
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
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

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
    print('[KWLM]:${getTag()}');
    print('[KWLM]:${getTag2()}');
    print('[KWLM]:${getTag3()}');
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void onPluginDemo() {
    print('[KWLM]:onPluginDemo111 Called!');
  }

  void onRandomDemo() {
    final Random random = Random();
    print('[KWLM]nextInt:${random.nextInt(100)}');
    print('[KWLM]nextDouble:${random.nextDouble()}');
    print('[KWLM]nextBool:${random.nextBool()}');
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

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
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
                const Text('onPluginDemo', style: TextStyle(fontSize: 30)),
                onTap: () {
                  onPluginDemo();
                }),
            GestureDetector(
                child:
                const Text('Random Demo', style: TextStyle(fontSize: 30)),
                onTap: () {
                  onRandomDemo();
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