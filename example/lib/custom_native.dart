import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CustomNative extends StatefulWidget {
  const CustomNative({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _CustomNativeState createState() {
    return _CustomNativeState();
  }
}

class _CustomNativeState extends State<CustomNative> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.blue,
              ),
            ),
            Expanded(
              flex: 2,
              child: getNativeViews(),
            ),
          ],
        )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          debugPrint('click button');
          Navigator.of(context).pushNamed("/a");
        },
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget getNativeViews() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'MyUiKitView',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'MyUiKitView',
      );
    }
    return Text('$defaultTargetPlatform is not yet supported by this plugin');
  }
}