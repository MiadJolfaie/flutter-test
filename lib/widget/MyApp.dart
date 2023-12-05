import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String text = "Stop Service";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Live menu'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    FlutterBackgroundService().invoke('setAsForground');
                  },
                  child: const Text('forGround Service')),
              ElevatedButton(
                  onPressed: () {
                    FlutterBackgroundService().invoke('setAsBackground');
                  },
                  child: const Text('backGound Service')),
              ElevatedButton(
                onPressed: () async {
                  final service = FlutterBackgroundService();

                  var isRunning = await service.isRunning();

                  if (isRunning) {
                    service.invoke('stopService');
                  } else {
                    service.startService();
                  }

                  if (!isRunning) {
                    text = 'Stop Service';
                  } else {
                    text = 'Start Service';
                  }
                },
                child: Text(text),
              )
            ],
          ),
        ),
      ),
    );
  }
}
