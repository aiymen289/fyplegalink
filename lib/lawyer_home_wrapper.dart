import 'package:flutter/material.dart';
import 'home_lawyer.dart'; // your existing file

class LawyerHomeWrapper extends StatefulWidget {
  const LawyerHomeWrapper({super.key});

  @override
  State<LawyerHomeWrapper> createState() => _LawyerHomeWrapperState();
}

class _LawyerHomeWrapperState extends State<LawyerHomeWrapper> {
  double sidebarWidth = 70;
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ---------------- Sidebar --------------------
          MouseRegion(
            onEnter: (_) => setState(() => sidebarWidth = 260),
            onExit: (_) => setState(() => sidebarWidth = 70),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: sidebarWidth,
              color: Colors.grey.shade900,
              padding: const EdgeInsets.only(top: 20),
              child: ListView(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // ---------------- Menu Groups ------------------
                  _buildMenuGroup("Personal & Professional Info", [
                    "Full Name",
                    "Profile Photo",
                    "CNIC / Bar Number",
                    "Qualification Details",
                    "Advocate Category",
                    "Years of Experience",
                    "Languages",
                    "Chambers Address",
                    "Contact Number & Email",
                  ]),

                  _buildMenuGroup("Case Management", [
                    "Active Cases",
                    "Closed Cases",
                    "Upcoming Hearings",
                    "Case Notes",
                    "Client Details",
                    "Upload Files",
                  ]),

                  _buildMenuGroup("Achievements", [
                    "Certificates",
                    "Awards",
                    "Specialized Courses",
                    "Bar Council Licenses",
                    "Workshops & Trainings",
                  ]),

                  _buildMenuGroup("Experience Section", [
                    "Past Law Firms",
                    "High-profile Cases",
                    "Specialized Domains",
                  ]),

                  _buildMenuGroup("Social Media Presence", [
                    "LinkedIn",
                    "Facebook",
                    "YouTube",
                    "Website",
                  ]),
                ],
              ),
            ),
          ),

          // ---------------- MAIN SCREEN (Dashboard) --------------------
          Expanded(
            child: Container(
              color: Colors.white,
              child: const LawyerHome(), // Your original logic preserved
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // SIDEBAR COMPONENTS
  // --------------------------------------------------------

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu, color: Colors.white, size: 30),
        if (sidebarWidth > 200)
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text(
              "LAWYER PANEL",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuGroup(String title, List<String> items) {
    return ExpansionTile(
      collapsedTextColor: Colors.white,
      iconColor: Colors.white,
      collapsedIconColor: Colors.white,
      textColor: Colors.white,
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: sidebarWidth > 200 ? 14 : 0, // hide text when collapsed
        ),
      ),
      leading: const Icon(Icons.folder, color: Colors.white),
      children: items.map((item) {
        return ListTile(
          title: Text(
            item,
            style: const TextStyle(color: Colors.white70),
          ),
        );
      }).toList(),
    );
  }
}
