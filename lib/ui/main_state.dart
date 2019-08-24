import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:location/location.dart';
import 'package:path_provider_ex/path_provider_ex.dart';
import 'package:permission/permission.dart';
import 'history_state.dart';

class MainScreen extends StatefulWidget {
  createState() => _MainState();
}

class _MainState extends State<MainScreen> with TickerProviderStateMixin {
  double _width,
      _lat, _lng; //storing last latitude and longitude to prevent listener to create the same position on the file by checking if the new position is different than the old one

  int _isTracking = 0; //0: not tracking, 1: Starting, 2: tracking.
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

    //requesting storage permission
    _requestStoragePermission();

    //getting SDCard path
    _getPath();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _width = size.width;
    // TODO: implement build
    return WillPopScope(
      onWillPop: () async {
        //when user press back button on Android, the app will show a dialog asking user if he want to fully exit the
        //application or just minimize it and let the location tracking in the background. to use this feature there is a
        //method channel in the MainActivity.java which listen for "sendToBackground" invoked method and move task to back

        //initializing exit or minimize status
        bool exit = false;

        await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Text("Do you want to quit?"),
                actions: <Widget>[
                  MaterialButton(
                    onPressed: () {
                      //invoking "sendToBackground" method to send task to back
                      _moveTaskToBackChannel.invokeMethod("sendToBackground");
                      //closing dialog
                      Navigator.pop(context);
                    },
                    child: Text("minimize"),
                  ),
                  MaterialButton(
                    onPressed: () {
                      //setting exit to true to fully close the application
                      exit = true;
                      //closing dialog
                      Navigator.pop(context);
                    },
                    child: Text("exit"),
                  )
                ],
              );
            });
        //if exit is true the the navigator will close the app, elase, it will do nothing.
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
                            Center(//animations behind the main yellow button.
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

                                  if (_isTracking != 1) {//to prevent user to press the button when locating is sill starting
                                    setState(() {
                                      _isTracking = _isTracking == 2 ? 0 : 1;
                                    });
                                    if (_isTracking == 0)
                                      _requestLocating();
                                    else
                                      _startStopLocationg();
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
                        child: Text(
                          _isTracking == 2
                              ? formatDate(_duration, [HH, ':', nn, ':', ss])
                              : "",
                          style: TextStyle(color: Colors.white),
                        ),
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

  void _requestLocating() {
    //initializing location if it's null
    if (_location == null) _location = Location();

    //checking for location permission
    _location.hasPermission().then((granted) {
      if (!granted)
        _location.requestPermission().then((status) {//permission not granted
          //requesting permission
          if (!status)
            _requestLocating(); //re request permission if denied
          else
            _location.requestService().then((val) {
              // request to enable location service
              if (val) //location service enabled
                _startStopLocationg(); //Start locating...
              else //location service not enabled
                _requestLocating(); //re request enable location service
            });
        });
      else //permission granted
        _location.requestService().then((val) {
          if (val)//location service enabled
            _startStopLocationg();//Start locating...
          else
            _requestLocating(); //location service not enabled => re request to enable location service
        });
    });
  }

  Future _startStopLocationg() async {
    //if is not tracking
    if (_isTracking == 1) {

      //preparing file
      //getting date
      final date = DateTime.now();

      //prepare file location (path + datetime + .txt)
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

      //creating file in storage
      await _file.create(recursive: true);

      //opening the file
      _open = _file.openWrite();

      //update ui to set (application is locating)
      setState(() {
        _isTracking = 2;
      });

      //resetting the counter
      _duration = DateTime(0);

      _startCounter();

      //resetting old latitude and old longitude to null;
      _lat = null;
      _lng = null;

      //starting location listener
      _startLocationListener();
    } else { //if the app is tracking
      setState(() {
        //updating the state to set => app is not locating
        _isTracking = 0;
      });

      //closing file.
      _open.flush();
      _open.close();
    }
  }

  Future<String> _getPath() async {
    //requesting for SDCard path
    final storageInfo = await PathProviderEx.getStorageInfo();
    //saving path
    _path = storageInfo[0].rootDir + "/track me files/";
    //returning path
    return storageInfo[0].rootDir + "/track me files/";
  }

  Future _requestStoragePermission() async {
    //defining current platform
    if (Platform.isIOS) {
      //checking permission status
      final isGranted =
          await Permission.getSinglePermissionStatus(PermissionName.Storage);
      if (isGranted != PermissionStatus.allow ||
          isGranted != PermissionStatus.always) {
        //if denied, request for it
       await Permission.requestSinglePermission(PermissionName.Storage);
      }
    } else if (Platform.isAndroid) {
      //checking permission status
      final isGranted =
          await Permission.getPermissionsStatus([PermissionName.Storage]);
      if (isGranted != PermissionStatus.allow ||
          isGranted != PermissionStatus.always) {
        //if denied, request for it
        await Permission.requestPermissions([PermissionName.Storage]);
      }
    }
  }

  Future _startCounter() async {
    while (_isTracking == 2) { //while the app is tracking
      await Future.delayed(Duration(seconds: 1));//waiting for one second
      setState(() {
        _duration = _duration.add(Duration(seconds: 1));//adding one seccond to the counter duration
      });
    }
  }

  void _startLocationListener() {
    //on location changed
    _location.onLocationChanged().listen((location) {

      if (_isTracking == 2){
      //if old position is recently initialized to null then create the new position the file.
      if (_lat == null) {
        //writing position to the file
        _file.writeAsStringSync(
            "${location.latitude},${location.longitude}\n",
            mode: FileMode.append);
      } else if (location.latitude != _lat || location.longitude != _lng) {
        //if the new position is dfferent than the old, create the position to the file.
        _file.writeAsStringSync(
            "${location.latitude},${location.longitude}\n",
            mode: FileMode.append);
      }

      //storing last position to compare it to the comming one.
      _lat = location.latitude;
      _lng = location.longitude;
      }

    });
  }
}
