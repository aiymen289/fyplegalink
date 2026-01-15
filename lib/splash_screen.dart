import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'role_selection.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Legalink',
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String appName = "Legalink";
  String displayedText = "";
  int currentIndex = 0;
  late Timer textTimer;

  final int numberOfParticles = 25;
  final Random random = Random();

  List<Offset> particlePositions = [];

  @override
  void initState() {
    super.initState();

    // Generate random particle positions
    for (int i = 0; i < numberOfParticles; i++) {
      particlePositions.add(Offset(random.nextDouble(), random.nextDouble()));
    }

    // Typewriter effect for app name
    textTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (currentIndex < appName.length) {
        setState(() {
          displayedText += appName[currentIndex];
          currentIndex++;
        });
      } else {
        textTimer.cancel();
      }
    });

    // Animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Scale bounce animation for icon
    _scaleAnimation =
        Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    // Fade-in animation for text
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Navigate after 5 seconds
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    textTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient (modern grey tones)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3A3A3A), // Darker grey
                  Color(0xFF8C8C8C) // Softer grey
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Floating particles (soft grey tones)
          ...particlePositions.map((pos) {
            return Positioned(
              left: pos.dx * MediaQuery.of(context).size.width,
              top: pos.dy * MediaQuery.of(context).size.height,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300.withOpacity(
                      0.2 + random.nextDouble() * 0.2), // soft grey
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
          // Center icon and text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Icon(
                    Icons.gavel,
                    size: 120,
                    color: Colors.grey.shade200, // soft grey icon
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    displayedText,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade100, // soft text color
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
