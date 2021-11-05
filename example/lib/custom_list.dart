import 'package:flutter/material.dart';

class CustomList extends StatefulWidget {
  const CustomList({Key? key, required this.title}) : super(key: key);

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
  _CustomListState createState() {
    print('[KWLM]:${getTag()}');
    print('[KWLM]:${getTag2()}');
    print('[KWLM]:${getTag3()}');
    return _CustomListState();
  }
}

class _CustomListState extends State<CustomList> {
  @override
  Widget build(BuildContext context) {
    Widget divider1 = Divider(color: Colors.blue,);
    Widget divider2 = Divider(color: Colors.green);
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: (
          ListView.separated(
            itemCount: 100,
            //列表项构造器
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                child: ListTile(title: Text("$index")),
                onTap: () {
                  debugPrint("click cell" + "$index");
                });
            },
            //分割器构造器
            separatorBuilder: (BuildContext context, int index) {
              return index%2 == 0?divider1:divider2;
            },
      )
    ),
    );
  }
}