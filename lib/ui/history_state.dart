import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:track_me/ui/text_view.dart';

class HistoryScreen extends StatefulWidget{
  final String path;

  const HistoryScreen({Key key, this.path}) : super(key: key);
  createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen>{

  List<File> _files = List();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    
    _dirContents(Directory(widget.path)).then((list){
      list.forEach((file){
       if (file is File)
         setState(() {
           _files.add(file);
         });
      });
      _files.sort((file1, file2) {
        return file2.path.compareTo(file1.path);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(title: Text("History"),),
      body: ListView.builder(itemBuilder: (context, index){
        final file = _files[index];
        final title = file.path.substring(file.path.lastIndexOf('/')+1);
        return ListTile(
          title: Text(title,),
          onTap: () async {
            final text = await file.readAsStringSync();
            Navigator.push(context, MaterialPageRoute(builder: (context) => TextViewScreen(title: title, text: text,)));
          },
        );
      },
      itemCount: _files.length,),
    );
  }

  Future<dynamic> _dirContents(Directory dir) {
    var files = <FileSystemEntity>[];
    var completer = new Completer();
    var lister = dir.list(recursive: false);
    lister.listen (
            (file) => files.add(file),
        // should also register onError
        onDone:   () => completer.complete(files)
    );
    return completer.future;
  }

}