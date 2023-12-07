import 'dart:async';
import 'package:flutter/material.dart';
import 'src/widget/MyApp.dart';
import 'package:url_strategy/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  await initializeNotifications();
  setHashUrlStrategy();
  runApp(const MyApp());
}
