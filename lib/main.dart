import "package:flutter/material.dart";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:  "My Application",
      home: Scaffold(
        appBar: AppBar(
          leading: Text("Hello"),
          backgroundColor: Colors.amberAccent,
        ),
        body: Center(
          child: Text("The Best of the best"),
        ),
      ),
    );
  }
}
