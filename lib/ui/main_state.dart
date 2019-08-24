import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:location/location.dart';
import 'package:path_provider_ex/path_provider_ex.dart';
import 'package:permission/permission.dart';
import 'package:track_me/utils/dimens.dart';
import 'history_state.dart';

class MainScreen extends StatefulWidget {
  createState() => _MainState();
}

class _MainState extends State<MainScreen> with TickerProviderStateMixin {
  double _heigt, _width, _lat, _lng;
  int _isTracking = 0;
  Location _location;
  File _file;
  IOSink _open;
  String _path = "";
  final _moveTaskToBackChannel = MethodChannel("android_app_retain");
  DateTime _duration = DateTime(1);

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _requestStoragePermission();

    _getPath();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _heigt = size.height;
    _width = size.width;
    // TODO: implement build
    return WillPopScope(
      onWillPop: () async {
        bool exit = false;
        await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Text("Do you want to quit?"),
                actions: <Widget>[
                  MaterialButton(
                    onPressed: () {
                      _moveTaskToBackChannel.invokeMethod("sendToBackground");
                      Navigator.pop(context);
                    },
                    child: Text("minimize"),
                  ),
                  MaterialButton(
                    onPressed: () {
                      exit = true;
                      Navigator.pop(context);
                    },
                    child: Text("exit"),
                  )
                ],
              );
            });
        print(exit);
        return Future.value(exit);
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xff84aaf5), Color(0xff0758f7)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter)),
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HistoryScreen(
                                    path: _path,
                                  ))),
                      child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Icon(
                          Icons.history,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        "Welcome back",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(
                        height: _width * .5,
                        child: Stack(
                          children: <Widget>[
                            Center(
                              child: _isTracking == 0
                                  ? Container()
                                  : _isTracking == 1
                                      ? SpinKitRipple(
                                          color: Colors.white,
                                          size: _width * .8,
                                          controller: AnimationController(
                                              vsync: this,
                                              duration: Duration(seconds: 1)),
                                        )
                                      : SpinKitPulse(
                                          color: Colors.white,
                                          size: _width * .9,
                                          controller: AnimationController(
                                              vsync: this,
                                              duration: Duration(seconds: 3)),
                                        ),
                            ),
                            Center(
                              child: InkWell(
                                onTap: () {
                                  if (_isTracking != 1) {
                                    setState(() {
                                      _isTracking = _isTracking == 2 ? 0 : 1;
                                    });
                                    _requestLocating();
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xfffbc02d)),
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2.0)),
                                      child: Padding(
                                        padding: EdgeInsets.all(_width * .1),
                                        child: Text(
                                          _isTracking == 2
                                              ? "Untrack"
                                              : _isTracking == 0
                                                  ? "Start"
                                                  : "Starting",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "Tracking is ${_isTracking == 2 ? "on" : "off"}",
                        style: TextStyle(color: Colors.white),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child:
                            Text(_isTracking == 2 ? formatDate(_duration, [HH, ':', nn, ':', ss]) : "", style: TextStyle(color: Colors.white),),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _location.dispose().then((_) {
      print(_);
      super.dispose();
    });
  }

  void _requestLocating() {
    if (_location == null) _location = Location();
    _location.hasPermission().then((granted) {
      if (!granted)
        _location.requestPermission().then((status) {
          if (!status)
            _requestLocating();
          else
            _location.requestService().then((val) {
              if (val)
                _startStopLocationg();
              else
                _requestLocating();
            });
        });
      else
        _location.requestService().then((val) {
          if (val)
            _startStopLocationg();
          else
            _requestLocating();
        });
    });
  }

  Future _startStopLocationg() async {
    if (_isTracking == 1) {
      final date = DateTime.now();

      _file = File("$_path${formatDate(date, [
        yy,
        '-',
        mm,
        "-",
        dd,
        " ",
        HH,
        ":",
        nn,
        ":",
        ss
      ])}.txt");
      await _file.create(recursive: true);
      _open = _file.openWrite();
      setState(() {
        _isTracking = 2;
      });
      _duration = DateTime(0);
      _startCounter();
      _lat = null;
      _lng = null;
      _location.onLocationChanged().listen((location) {
        if (_lat == null) {
          _file.writeAsStringSync(
              "${location.latitude},${location.longitude}\n",
              mode: FileMode.append);
        }
        else if(location.latitude != _lat || location.longitude != _lng){
          _file.writeAsStringSync(
              "${location.latitude},${location.longitude}\n",
              mode: FileMode.append);
        }
        _lat = location.latitude;
        _lng = location.longitude;
      });
    } else {
      setState(() {
        _isTracking = 0;
      });
      _location.dispose().then((val) {
        print(val);
      });
      _open.flush();
      _open.close();
    }
  }

  Future<String> _getPath() async {
    final storageInfo = await PathProviderEx.getStorageInfo();
    _path = storageInfo[0].rootDir + "/track me files/";
    return storageInfo[0].rootDir + "/track me files/";
  }

  Future _requestStoragePermission() async {
    if (Platform.isIOS) {
      final isGranted =
          await Permission.getSinglePermissionStatus(PermissionName.Storage);
      if (isGranted != PermissionStatus.allow ||
          isGranted != PermissionStatus.always) {
        final result =
            await Permission.requestSinglePermission(PermissionName.Storage);
      }
    } else if (Platform.isAndroid) {
      final isGranted =
          await Permission.getPermissionsStatus([PermissionName.Storage]);
      if (isGranted != PermissionStatus.allow ||
          isGranted != PermissionStatus.always) {
        final result =
            await Permission.requestPermissions([PermissionName.Storage]);
      }
    }
  }

  Future _startCounter() async {
    while (_isTracking == 2) {
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _duration = _duration.add(Duration(seconds: 1));
      });
    }
  }
}
