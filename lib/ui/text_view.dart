import 'package:flutter/material.dart';

class TextViewScreen extends StatelessWidget {
  final String text, title;

  const TextViewScreen({Key key, this.text, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
              child: SizedBox(
                  width: double.infinity,
                  child: Text(text)
              ))),
    );
  }
}
