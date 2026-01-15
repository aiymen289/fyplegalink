import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB2lV_i2_QQYgn5q1P8Uk587A_UOCjsqSA",
      authDomain: "legalinkapp-a135b.firebaseapp.com",
      projectId: "legalinkapp-a135b",
      storageBucket: "legalinkapp-a135b.appspot.com",
      messagingSenderId: "57159131515",
      appId: "1:57159131515:web:857d40e12b1619a6d31dde",
      measurementId: "G-L2SY3W9Z5N",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LegaLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: SplashScreen(),
    );
  }
}
