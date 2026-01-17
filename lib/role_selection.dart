import 'package:flutter/material.dart';
import 'register_lawyer.dart';
import 'register_client.dart';
import 'register_admin.dart';
import 'login_page.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dark gradient background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.blueGrey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo placeholder (optional)
                const SizedBox(height: 20),
                const Text(
                  "Choose a Role", // Name of the app
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                // Cards with icons & text
                RoleCard(
                  title: "Citizen",
                  icon: Icons.person,
                  gradientColors: [Colors.greenAccent, Colors.teal],
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterClient()));
                  },
                ),
                const SizedBox(height: 20),
                RoleCard(
                  title: "Lawyer",
                  icon: Icons.gavel,
                  gradientColors: [Colors.purpleAccent, Colors.deepPurple],
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterLawyer()));
                  },
                ),
                const SizedBox(height: 20),
                RoleCard(
                  title: "Admin",
                  icon: Icons.admin_panel_settings,
                  gradientColors: [Colors.orangeAccent, Colors.deepOrange],
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterAdmin()));
                  },
                ),

                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginPage()));
                  },
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Role Card Widget with icon on left, text on right
class RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(width: 15),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
