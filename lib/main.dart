import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


const EVENTS_KEY = "fetch_events";


@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  var taskId = task.taskId;
  var timeout = task.timeout;
  if (timeout) {
    if (kDebugMode) {
      print("[BackgroundFetch] Headless task timed-out: $taskId");
    }
    BackgroundFetch.finish(taskId);
    return;
  }

  if (kDebugMode) {
    print("[BackgroundFetch] Headless event received: $taskId");
  }

  var timestamp = DateTime.now();

  var prefs = await SharedPreferences.getInstance();

  var events = <String>[];
  var json = prefs.getString(EVENTS_KEY);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }
  events.insert(0, "$taskId@$timestamp [Headless]");
  prefs.setString(EVENTS_KEY, jsonEncode(events));

  if (taskId == 'flutter_background_fetch') {
    BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "com.transistorsoft.customtask",
        delay: 5000,
        periodic: false,
        forceAlarmManager: false,
        stopOnTerminate: false,
        enableHeadless: true
    ));
  }
  BackgroundFetch.finish(taskId);
}

void main() {
  runApp(const MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _enabled = true;
  int _status = 0;
  List<String> _events = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    var prefs = await SharedPreferences.getInstance();
    var json = prefs.getString(EVENTS_KEY);
    if (json != null) {
      setState(() {
        _events = jsonDecode(json).cast<String>();
      });
    }

    try {
      var status = await BackgroundFetch.configure(BackgroundFetchConfig(
          minimumFetchInterval: 15,
          forceAlarmManager: false,
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.NONE
      ), _onBackgroundFetch, _onBackgroundFetchTimeout);
      if (kDebugMode) {
        print('[BackgroundFetch] configure success: $status');
      }
      setState(() {
        _status = status;
      });

      BackgroundFetch.scheduleTask(TaskConfig(
          taskId: "com.transistorsoft.customtask",
          delay: 10000,
          periodic: false,
          forceAlarmManager: true,
          stopOnTerminate: false,
          enableHeadless: true
      ));
    } on Exception catch(e) {
      if (kDebugMode) {
        print("[BackgroundFetch] configure ERROR: $e");
      }
    }
    if (!mounted) return;
  }

  void _onBackgroundFetch(String taskId) async {
    var prefs = await SharedPreferences.getInstance();
    var timestamp = DateTime.now();
    if (kDebugMode) {
      print("[BackgroundFetch] Event received: $taskId");
    }
    setState(() {
      _events.insert(0, "$taskId@${timestamp.toString()}");
    });
    prefs.setString(EVENTS_KEY, jsonEncode(_events));

    if (taskId == "flutter_background_fetch") {
      var url = Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'});

      var response = await http.get(url);
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        var itemCount = jsonResponse['totalItems'];
        if (kDebugMode) {
          print('Number of books about http: $itemCount.');
        }
      } else {
        if (kDebugMode) {
          print('Request failed with status: ${response.statusCode}.');
        }
      }
    }
    BackgroundFetch.finish(taskId);
  }

  void _onBackgroundFetchTimeout(String taskId) {
    if (kDebugMode) {
      print("[BackgroundFetch] TIMEOUT: $taskId");
    }
    BackgroundFetch.finish(taskId);
  }

  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((status) {
        if (kDebugMode) {
          print('[BackgroundFetch] start success: $status');
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('[BackgroundFetch] start FAILURE: $e');
        }
      });
    } else {
      BackgroundFetch.stop().then((status) {
        if (kDebugMode) {
          print('[BackgroundFetch] stop success: $status');
        }
      });
    }
  }

  void _onClickStatus() async {
    var status = await BackgroundFetch.status;
    if (kDebugMode) {
      print('[BackgroundFetch] status: $status');
    }
    setState(() {
      _status = status;
    });
    BackgroundFetch.scheduleTask(TaskConfig(
        taskId: "com.transistorsoft.customtask",
        delay: 10000,
        periodic: false,
        forceAlarmManager: false,
        stopOnTerminate: false,
        enableHeadless: true
    ));
  }

  void _onClickClear() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.remove(EVENTS_KEY);
    setState(() {
      _events = [];
    });
  }
  @override
  Widget build(BuildContext context) {
    const EMPTY_TEXT = Center(child: Text('Waiting for fetch events.  Simulate one.\n [Android] \$ ./scripts/simulate-fetch\n [iOS] XCode->Debug->Simulate Background Fetch'));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
            title: const Text('BackgroundFetch Example', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
            actions: <Widget>[
              Switch(value: _enabled, onChanged: _onClickEnable),
            ]
        ),
        body: (_events.isEmpty) ? EMPTY_TEXT : ListView.builder(
            itemCount: _events.length,
            itemBuilder: (context, index) {
              var event = _events[index].split("@");
              return InputDecorator(
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 5.0, top: 5.0, bottom: 5.0),
                      labelStyle: const TextStyle(color: Colors.blue, fontSize: 20.0),
                      labelText: "[${event[0].toString()}]"
                  ),
                  child: Text(event[1], style: const TextStyle(color: Colors.black, fontSize: 16.0))
              );
            }
        ),
        bottomNavigationBar: BottomAppBar(
            child: Container(
                padding: const EdgeInsets.only(left: 5.0, right:5.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      ElevatedButton(onPressed: _onClickStatus, child: Text('Status: $_status')),
                      ElevatedButton(onPressed: _onClickClear, child: const Text('Clear'))
                    ]
                )
            )
        ),
      ),
    );
  }
}
