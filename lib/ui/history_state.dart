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

  List<File> _files = List();//creating list of text files

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    //listing directory content
    _dirContents(Directory(widget.path)).then((list){
      list.forEach((file){
        //putting the object in files list if it isa file
       if (file is File)
         setState(() {
           _files.add(file);
         });
      });
      //sorting list by name (created date time)
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
        //getting file name
        final title = file.path.substring(file.path.lastIndexOf('/')+1);
        return ListTile(
          title: Text(title,),
          onTap: () async {
            //getting text from file and send it to textview screen
            final text = await file.readAsStringSync();
            Navigator.push(context, MaterialPageRoute(builder: (context) => TextViewScreen(title: title, text: text,)));
          },
        );
      },
      itemCount: _files.length,),
    );
  }

  Future<dynamic> _dirContents(Directory dir) {
    List<FileSystemEntity> files = <FileSystemEntity>[];
    final completer = new Completer();
    final lister = dir.list(recursive: false);
    lister.listen (
            (file) => files.add(file),
        onDone:   () => completer.complete(files)
    );
    return completer.future;
  }

}