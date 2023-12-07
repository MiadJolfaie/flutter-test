import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// WebSocket channel
const String websocketUrl =
    'wss://socket.live-menu.ir?ogid=EF4653F9-1058-4191-9795-DB425C06EA76';
late IOWebSocketChannel channel;
bool isWebSocketConnected = false;
String socketStatus = "Socket Status: Connecting...";

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()!
      .requestNotificationsPermission();

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  clearLogger();
  await service.configure(
    iosConfiguration: IosConfiguration(),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
  );
}

void clearLogger() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  await preferences.setStringList('log', <String>[]);
}

void addLogger(String str) async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(str);
  await preferences.setStringList('log', log);
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();

      showForegroundNotification();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Function to connect to WebSocket
  Future<void> connectToWebSocket() async {
    channel = IOWebSocketChannel.connect(websocketUrl);
    isWebSocketConnected = true;

    addLogger('WebSocket connection started');

    channel.stream.listen(
      (data) {
        print('WebSocket data: $data');

        displayNotificationFromWebSocketMessage(data);

        addLogger('WebSocket data: $data');

        socketStatus = "Socket Status: Connected";
        // Handle WebSocket data
      },
      onDone: () {
        print('WebSocket closed');

        addLogger('WebSocket closed');

        // Handle WebSocket closure
        isWebSocketConnected = false;

        socketStatus =
            "Socket Status: Disconnected"; // Update the socket status

        // Attempt to reconnect after a delay
        Timer(const Duration(seconds: 5), () {
          if (!isWebSocketConnected) {
            connectToWebSocket();
          }
        });
      },
      onError: (error) {
        print('WebSocket error: $error');

        addLogger('WebSocket error: $error');

        socketStatus = "Socket Status: Error";
        // Handle WebSocket errors
      },
    );
  }

  // Connect to WebSocket when the service starts
  connectToWebSocket();

  service.on('stopService').listen((event) {
    // Stop WebSocket connection when stopping the service
    channel.sink.close();
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // service.setForegroundNotificationInfo(
        //   title: 'My app service',
        //   content: 'updated at ${DateTime.now()}',
        // );
        // updateForegroundNotificationContent();
      }
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": 'miad',
      },
    );
  });
}

void showForegroundNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    '1456454765876960976076985876473754',
    'Foreground Service',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Foreground Service',
    'Foreground Service is running',
    platformChannelSpecifics,
  );
}

void updateForegroundNotificationContent() {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    '1456454765876960976076985876473754',
    'Foreground Service',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  flutterLocalNotificationsPlugin.show(
    0,
    'My app service',
    'updated at ${DateTime.now()}',
    platformChannelSpecifics,
  );
}

void displayNotificationFromWebSocketMessage(String message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    '1456454765876960976076985876473754',
    'WebSocket Message',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  try {
    // Parse the JSON message
    final Map<String, dynamic> messageData = json.decode(message);

    // Access the "tableid" field
    final String tableId = messageData['data']['tableid'];

    await flutterLocalNotificationsPlugin.show(
      1,
      'WebSocket Message',
      'Received: Table ID - $tableId',
      platformChannelSpecifics,
    );
  } catch (e) {
    print('Error parsing WebSocket message: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String text = "Stop Service";
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Service App'),
        ),
        body: Column(
          children: [
            StreamBuilder<Map<String, dynamic>?>(
              stream: FlutterBackgroundService().on('update'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!;
                String? device = data["device"];
                DateTime? date = DateTime.tryParse(data["current_date"]);
                return Column(
                  children: [
                    Text(device ?? 'Unknown'),
                    Text(date.toString()),
                  ],
                );
              },
            ),
            ElevatedButton(
              child: const Text("Foreground Mode"),
              onPressed: () {
                FlutterBackgroundService().invoke("setAsForeground");
              },
            ),
            ElevatedButton(
              child: const Text("Background Mode"),
              onPressed: () {
                FlutterBackgroundService().invoke("setAsBackground");
              },
            ),
            ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                if (isRunning) {
                  service.invoke("stopService");
                } else {
                  service.startService();
                }

                if (!isRunning) {
                  text = 'Stop Service';
                } else {
                  text = 'Start Service';
                }
                setState(() {});
              },
            ),
            const Expanded(
              child: LogView(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.play_arrow),
        ),
      ),
    );
  }
}

class LogView extends StatefulWidget {
  const LogView({Key? key}) : super(key: key);

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final Timer timer;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.reload();
      logs = sp.getStringList('log') ?? [];
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs.elementAt(index);
        return Text(log);
      },
    );
  }
}
