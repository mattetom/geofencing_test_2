// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:geofencing/geofencing.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String geofenceState = 'N/A';
  List<String> registeredGeofences = [];
  double latitude = 45.675234532513926;
  double longitude = 8.952928782802026;
  double radius = 100.0;
  ReceivePort port = ReceivePort();
  final List<GeofenceEvent> triggers = <GeofenceEvent>[
    GeofenceEvent.enter,
    GeofenceEvent.exit
  ];
  final AndroidGeofencingSettings androidSettings = AndroidGeofencingSettings(
    initialTrigger: <GeofenceEvent>[
      GeofenceEvent.enter,
      GeofenceEvent.exit,
    ],
    loiteringDelay: 0,
    notificationResponsiveness: 0,
  );

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      'geofencing_send_port',
    );
    port.listen((dynamic data) async {
      print('Event: $data');
      setState(() {
        geofenceState = data;
      });
    });
    initPlatformState();
  }

  void registerGeofence() async {
    final firstPermission = await Permission.locationWhenInUse.request();
    final secondPermission = await Permission.locationAlways.request();
    if (firstPermission.isGranted && secondPermission.isGranted) {
      await GeofencingManager.registerGeofence(
        GeofenceRegion(
          'mtv',
          latitude,
          longitude,
          radius,
          triggers,
          androidSettings,
        ),
        callback,
      );
      final registeredIds = await GeofencingManager.getRegisteredGeofenceIds();
      setState(() {
        registeredGeofences = registeredIds;
      });
    }
  }

  void unregisteGeofence() async {
    await GeofencingManager.removeGeofenceById('mtv');
    final registeredIds = await GeofencingManager.getRegisteredGeofenceIds();
    setState(() {
      registeredGeofences = registeredIds;
    });
  }

  @pragma('vm:entry-point')
  static void callback(List<String> ids, Location l, GeofenceEvent e) async {
    print('Fences: $ids Location $l Event: $e');
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails('your channel id', 'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await flutterLocalNotificationsPlugin.show(
        0, 'Geofencing', 'Event: $e', notificationDetails,
        payload: 'item x');
    final SendPort send =
        IsolateNameServer.lookupPortByName('geofencing_send_port');
    send?.send(e.toString());
  }

  Future<void> initPlatformState() async {
    print('Initializing...');
    await GeofencingManager.initialize();
    final registeredIds = await GeofencingManager.getRegisteredGeofenceIds();
    setState(() {
      registeredGeofences = registeredIds;
    });
    print('Initialization done');
  }

  String numberValidator(String value) {
    if (value == null) {
      return null;
    }
    final num a = num.tryParse(value);
    if (a == null) {
      return '"$value" is not a valid number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Geofencing Example'),
          ),
          body: Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('Current state: $geofenceState'),
                    Center(
                      child: TextButton(
                        child: const Text('Register'),
                        onPressed: registerGeofence,
                      ),
                    ),
                    Text('Registered Geofences: $registeredGeofences'),
                    Center(
                      child: TextButton(
                        child: const Text('Unregister'),
                        onPressed: unregisteGeofence,
                      ),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Latitude',
                      ),
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: latitude.toString()),
                      onChanged: (String s) {
                        latitude = double.tryParse(s);
                      },
                    ),
                    TextField(
                        decoration:
                            const InputDecoration(hintText: 'Longitude'),
                        keyboardType: TextInputType.number,
                        controller:
                            TextEditingController(text: longitude.toString()),
                        onChanged: (String s) {
                          longitude = double.tryParse(s);
                        }),
                    TextField(
                        decoration: const InputDecoration(hintText: 'Radius'),
                        keyboardType: TextInputType.number,
                        controller:
                            TextEditingController(text: radius.toString()),
                        onChanged: (String s) {
                          radius = double.tryParse(s);
                        }),
                  ]))),
    );
  }
}
