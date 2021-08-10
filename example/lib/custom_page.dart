import 'package:flutter/material.dart';

class CustomPage extends StatefulWidget {
  const CustomPage({Key key, this.title}) : super(key: key);

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
  _CustomPageState createState() {
    print('[KWLM]:${getTag()}');
    print('[KWLM]:${getTag2()}');
    print('[KWLM]:${getTag3()}');
    return _CustomPageState();
  }
}

class _CustomPageState extends State<CustomPage> {
  @override
  Widget build(BuildContext context) {
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
                  GestureDetector(
                      child:
                      const Text(
                          'Pop Widget', style: TextStyle(fontSize: 30)),
                      onTap: () {
                        Navigator.of(context).pop();
                      }),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: "用户名",
                        hintText: "用户名或邮箱",
                        prefixIcon: Icon(Icons.person)
                    ),
                      onChanged: (v) {
                        print("onChange: $v");
                      }
                  ),
                  TextField(
                    decoration: InputDecoration(
                        labelText: "密码",
                        hintText: "您的登录密码",
                        prefixIcon: Icon(Icons.lock)
                    ),
                    obscureText: true,
                  ),
                ]),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          debugPrint('click button');
        },
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}