import 'dart:math';
import 'package:flutter/material.dart';
import 'role_selection.dart'; // Ensure this file exists for navigation

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;

  // List of icons to use for the scattered background
  final List<String> baseIconUrls = [
    'https://img.icons8.com/ios-filled/100/ffffff/gavel.png', // Gavel/Law
    'https://img.icons8.com/ios-filled/100/ffffff/document.png', // Document
    'https://img.icons8.com/ios-filled/100/ffffff/idea.png', // Idea/Lightbulb
    'https://img.icons8.com/ios-filled/100/ffffff/briefcase.png', // Briefcase
    'https://img.icons8.com/ios-filled/100/ffffff/handcuffs.png', // Handcuffs
    'https://img.icons8.com/ios-filled/100/ffffff/security-checked.png', // Shield/Security
    'https://img.icons8.com/ios-filled/100/ffffff/chat.png', // Chat
    'https://img.icons8.com/ios-filled/100/ffffff/user-male-circle.png', // User
  ];

  // Create a large list of icons for a dense background pattern (e.g., 30 icons)
  late final List<String> iconUrls = List.generate(30, (index) => baseIconUrls[index % baseIconUrls.length]);

  final Random _random = Random();
  late List<Offset> positions = [];
  bool _positionsInitialized = false;

  @override
  void initState() {
    super.initState();

    // Text scale and float animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });

    // Floating animation for icons (reduced range for subtlety)
    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    // Navigate to RoleSelection after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // New: Random position generator to fill the screen while avoiding the center.
  void _generateRandomPositions(double screenWidth, double screenHeight) {
    if (_positionsInitialized) return;

    // Define a central exclusion zone (60% of screen) to keep the text clear
    const double centerFraction = 0.60;
    final double centerWidth = screenWidth * centerFraction;
    final double centerHeight = screenHeight * centerFraction;

    final Rect centerRegion = Rect.fromCenter(
      center: Offset(screenWidth / 2, screenHeight / 2),
      width: centerWidth,
      height: centerHeight,
    );

    // Max icon size (for bounding box check)
    final double iconSizeMax = 70.0; 

    positions = List.generate(iconUrls.length, (index) {
      double left;
      double top;
      
      // Loop until a position is found outside the central region
      do {
        // Generate random position within screen bounds
        top = _random.nextDouble() * (screenHeight - iconSizeMax);
        left = _random.nextDouble() * (screenWidth - iconSizeMax);
      } while (centerRegion.contains(Offset(left, top))); 

      return Offset(left, top);
    });

    _positionsInitialized = true;
  }
  
  // Floating icon widget - now uses random positions, size, and opacity
  Widget floatingIcon(String url, Offset position, double size, double opacity, double animationOffset) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Positioned(
          // Apply animation with a slight randomized offset for non-uniform movement
          top: position.dy + _floatAnimation.value * animationOffset, 
          left: position.dx,
          child: Image.network(
            url,
            width: size,
            // Use subtle opacity to mimic the background texture in the sample image
            color: Colors.white.withOpacity(opacity), 
            errorBuilder: (context, error, stackTrace) {
              // Fallback for broken network images
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Removed rightCornerIcons() and all hardcoded icon placements

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _generateRandomPositions(constraints.maxWidth, constraints.maxHeight);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1C1C1C), Color(0xFF2E2E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // --- 1. Randomly scattered and floating background icons ---
                if (_positionsInitialized)
                  for (int i = 0; i < iconUrls.length; i++)
                    floatingIcon(
                      iconUrls[i],
                      positions[i],
                      // Random size (40-65)
                      40 + _random.nextDouble() * 25, 
                      // Random opacity (0.05 to 0.15) for a very subtle background effect
                      0.05 + _random.nextDouble() * 0.10, 
                      // Random animation multiplier for varied float speed
                      1.0 + _random.nextDouble() * 0.5,
                    ),

                // --- 2. Center Animated Text ---
                Center(
                  child: Container(
                    // Added a dark circular overlay back for better contrast and glow effect
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3), 
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Text(
                        "LegalLink", // Changed back to LegalLink as per image
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 50, // Slightly larger
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.white70.withOpacity(0.8),
                              offset: const Offset(0, 0),
                              blurRadius: 30, // Stronger glow
                            ),
                          ],
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}