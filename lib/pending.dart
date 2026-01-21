import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_lawyer.dart';
import 'lawyer_home_wrapper.dart';

import 'register_client.dart';
import 'home_client.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool rejectionShown = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again.")),
      );
    }

    // STEP 1 — Check if user is a lawyer
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('lawyers').doc(user.uid).get(),
      builder: (context, lawyerSnap) {
        if (lawyerSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        bool isLawyer = lawyerSnap.data != null && lawyerSnap.data!.exists;

        // STEP 2 — Stream lawyer/client data
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection(isLawyer ? 'lawyers' : 'clients')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // REJECTED
            if (!snapshot.hasData || !snapshot.data!.exists) {
              if (!rejectionShown) {
                rejectionShown = true;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Sorry, your registration was rejected."),
                    backgroundColor: Colors.red,
                  ),
                );

                Future.delayed(const Duration(seconds: 2), () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isLawyer
                          ? const RegisterLawyer()
                          : const RegisterClient(),
                    ),
                  );
                });
              }

              return const Scaffold(
                body: Center(child: Text("Processing...")),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final isApproved = data['isApproved'] ?? false;

            // APPROVED → redirect to respective home
            if (isApproved) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isLawyer
                        ? const LawyerHomeWrapper()
                        : const ClientHome(),
                  ),
                );
              });

              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // STILL PENDING → Show waiting screen
            return Scaffold(
              backgroundColor: const Color(0xFF0F0F0F),
              appBar: AppBar(
                title: const Text("Approval Status"),
                backgroundColor: const Color(0xFF0F0F0F),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time,
                        size: 80, color: Colors.amber),
                    const SizedBox(height: 20),
                    Text(
                      isLawyer
                          ? "Lawyer application is under review."
                          : "Client registration is under review.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Please wait until admin approves your account.",
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
