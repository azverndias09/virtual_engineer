import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:motor_app/analysisPage.dart';
import 'package:motor_app/graphPage.dart';

import 'package:motor_app/real_time_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set the database URL if not automatically configured
    // FirebaseDatabase database = FirebaseDatabase.instance;

    // FirebaseDatabase database = FirebaseDatabase.instanceFor(
    //   app: Firebase.app(),
    //   databaseURL:
    //       "https://esptrial1-e2df8-default-rtdb.asia-southeast1.firebasedatabase.app/",
    // );
    FirebaseDatabase database = FirebaseDatabase.instance;
    // database.setPersistenceEnabled(true);

    print("✅ Firebase Initialized Successfully");
    print("🌐 Database URL: ${database.databaseURL}");
  } catch (e) {
    print("❌ Firebase Initialization Error: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase Read Data',
      home: RealTimeDataPage(),
    );
  }
}
