# Flutter Background Fetch

Background Fetch is a very simple plugin which will awaken an app in the background about every 15 minutes, providing a short period of background running-time. This plugin will execute your provided callbackFn whenever a background-fetch event occurs.

🆕 Background Fetch now provides a scheduleTask method for scheduling arbitrary "one-shot" or periodic tasks.

## IOS

1. There is no way to increase the rate which a fetch-event occurs and this plugin sets the rate to the most frequent possible — you will never receive an event faster than 15 minutes. The operating-system will automatically throttle the rate the background-fetch events occur based upon usage patterns. Eg: if user hasn't turned on their phone for a long period of time, fetch events will occur less frequently.

2. scheduleTask seems only to fire when the device is plugged into power. scheduleTask is designed for low-priority tasks and will never run as frequently as you desire.

3. The default fetch task will run far more frequently.

4. ⚠️ When your app is terminated, iOS no longer fires events — There is no such thing as stopOnTerminate: false for iOS.

5. iOS can task days before Apple's machine-learning algorithm settles in and begins regularly firing events. Do not sit staring at your logs waiting for an event to fire. If your simulated events work, that's all you need to know that everything is correctly configured.

6. If the user doesn't open your iOS app for long periods of time, iOS will stop firing events.

## Android

The Android plugin provides a Headless implementation allowing you to continue handling events even after app-termination.

## Installing the plugin

pubspec.yaml:

   ```
   dependencies:
  background_fetch: '^1.1.3'
  ```

Or latest from Git:

   ```
   dependencies:
  background_fetch:
    git:
      url: https://github.com/transistorsoft/flutter_background_fetch
   ```

## Example

   ```
   import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:background_fetch/background_fetch.dart';

// [Android-only] This "Headless Task" is run when the Android app is terminated with `enableHeadless: true`
// Be sure to annotate your callback function to avoid issues in release mode on Flutter >= 3.3.0
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  if (isTimeout) {
    // This task has exceeded its allowed running-time.  
    // You must stop what you're doing and immediately .finish(taskId)
    print("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }  
  print('[BackgroundFetch] Headless event received.');
  // Do your work here...
  BackgroundFetch.finish(taskId);
}

void main() {
  // Enable integration testing with the Flutter Driver extension.
  // See https://flutter.io/testing/ for more info.
  runApp(new MyApp());

  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _enabled = true;
  int _status = 0;
  List<DateTime> _events = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Configure BackgroundFetch.
    int status = await BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE
    ), (String taskId) async {  // <-- Event handler
      // This is the fetch-event callback.
      print("[BackgroundFetch] Event received $taskId");
      setState(() {
        _events.insert(0, new DateTime.now());
      });
      // IMPORTANT:  You must signal completion of your task or the OS can punish your app
      // for taking too long in the background.
      BackgroundFetch.finish(taskId);
    }, (String taskId) async {  // <-- Task timeout handler.
      // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
      print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
      BackgroundFetch.finish(taskId);
    });
    print('[BackgroundFetch] configure success: $status');
    setState(() {
      _status = status;
    });        

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    } else {
      BackgroundFetch.stop().then((int status) {
        print('[BackgroundFetch] stop success: $status');
      });
    }
  }

  void _onClickStatus() async {
    int status = await BackgroundFetch.status;
    print('[BackgroundFetch] status: $status');
    setState(() {
      _status = status;
    });
  }
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('BackgroundFetch Example', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.amberAccent,
          brightness: Brightness.light,
          actions: <Widget>[
            Switch(value: _enabled, onChanged: _onClickEnable),
          ]
        ),
        body: Container(
          color: Colors.black,
          child: new ListView.builder(
              itemCount: _events.length,
              itemBuilder: (BuildContext context, int index) {
                DateTime timestamp = _events[index];
                return InputDecorator(
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10.0, top: 10.0, bottom: 0.0),
                        labelStyle: TextStyle(color: Colors.amberAccent, fontSize: 20.0),
                        labelText: "[background fetch event]"
                    ),
                    child: new Text(timestamp.toString(), style: TextStyle(color: Colors.white, fontSize: 16.0))
                );
              }
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            children: <Widget>[
              RaisedButton(onPressed: _onClickStatus, child: Text('Status')),
              Container(child: Text("$_status"), margin: EdgeInsets.only(left: 20.0))
            ]
          )
        ),
      ),
    );
  }
}
   ```

### Executing Custom Tasks

In addition to the default background-fetch task defined by BackgroundFetch.configure, you may also execute your own arbitrary "oneshot" or periodic tasks (iOS requires additional Setup Instructions). However, all events will be fired into the Callback provided to BackgroundFetch#configure:

### iOS:

1. scheduleTask on iOS seems only to run when the device is plugged into power.

2. scheduleTask on iOS are designed for low-priority tasks, such as purging cache files — they tend to be unreliable for mission-critical tasks. scheduleTask will never run as frequently as you want.

3. The default fetch event is much more reliable and fires far more often.

4. scheduleTask on iOS stop when the user terminates the app. There is no such thing as stopOnTerminate: false for iOS.

   ```
   // Step 1:  Configure BackgroundFetch as usual.
   int status = await BackgroundFetch.configure(BackgroundFetchConfig(
   minimumFetchInterval: 15
   ), (String taskId) async {  // <-- Event callback.
   // This is the fetch-event callback.
   print("[BackgroundFetch] taskId: $taskId");

   // Use a switch statement to route task-handling.
   switch (taskId) {
   case 'com.transistorsoft.customtask':
   print("Received custom task");
   break;
   default:
   print("Default fetch task");
   }
   // Finish, providing received taskId.
   BackgroundFetch.finish(taskId);
   }, (String taskId) async {  // <-- Event timeout callback
   // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
   print("[BackgroundFetch] TIMEOUT taskId: $taskId");
   BackgroundFetch.finish(taskId);
   });

   // Step 2:  Schedule a custom "oneshot" task "com.transistorsoft.customtask" to execute 5000ms from now.
   BackgroundFetch.scheduleTask(TaskConfig(
   taskId: "com.transistorsoft.customtask",
   delay: 5000  // <-- milliseconds
   ));
   ```