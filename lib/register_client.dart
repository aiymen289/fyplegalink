import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pending.dart';

class RegisterClient extends StatefulWidget {
  const RegisterClient({super.key});

  @override
  State<RegisterClient> createState() => _RegisterClientState();
}

class _RegisterClientState extends State<RegisterClient> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  int currentStep = 0;

  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();

  final cnicC = TextEditingController();
  Uint8List? cnicFront;
  Uint8List? cnicBack;
  String? frontName;
  String? backName;

  final phoneC = TextEditingController(text: "+92");
  final noteC = TextEditingController();
  final addressC = TextEditingController();
  String? caseType;

  List<String> caseTypes = [
    "Divorce and dissolution of marriage",
    "Child custody and support",
    "Domestic violence"
  ];

  // FORMATTERS ---------------------------------
  String formatCNIC(String input) {
    input = input.replaceAll('-', '');
    if (input.length > 5 && input.length <= 12) {
      return "${input.substring(0, 5)}-${input.substring(5)}";
    } else if (input.length > 12) {
      return "${input.substring(0, 5)}-${input.substring(5, 12)}-${input.substring(12)}";
    }
    return input;
  }

  String formatPhone(String input) {
    input = input.replaceAll('+92', '').replaceAll(' ', '');
    if (input.startsWith("03")) return "+92${input.substring(1)}";
    if (input.length == 10) return "+92$input";
    return "+92$input";
  }

  // PASSWORD VALIDATION
  bool isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[0-9])(?=.*[!@#\$&*~]).{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> pickFront() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (r != null) {
      setState(() {
        cnicFront = r.files.first.bytes!;
        frontName = r.files.first.name;
      });
    }
  }

  Future<void> pickBack() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (r != null) {
      setState(() {
        cnicBack = r.files.first.bytes!;
        backName = r.files.first.name;
      });
    }
  }

  bool validateStep(int step) {
    switch (step) {
      case 0:
        if (nameC.text.trim().isEmpty) return false;
        if (!emailC.text.contains("@")) return false;
        if (!isPasswordValid(passC.text.trim())) return false;
        return true;
      case 1:
        if (cnicC.text.length != 15) return false;
        if (cnicFront == null || cnicBack == null) return false;
        return true;
      case 2:
        if (!phoneC.text.startsWith("+92")) return false;
        if (phoneC.text.length != 13) return false;
        if (addressC.text.trim().isEmpty) return false;
        return true;
      default:
        return true;
    }
  }

  Future<void> registerClient() async {
    if (!_formKey.currentState!.validate() ||
        cnicFront == null ||
        cnicBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields & upload images")),
      );
      return;
    }

    try {
      final user = await _auth.createUserWithEmailAndPassword(
        email: emailC.text.trim(),
        password: passC.text.trim(),
      );

      final uid = user.user!.uid;

      String frontBase64 = base64Encode(cnicFront!);
      String backBase64 = base64Encode(cnicBack!);

      await _firestore.collection('clients').doc(uid).set({
        'fullName': nameC.text.trim(),
        'email': emailC.text.trim(),
        'phone': phoneC.text.trim(),
        'cnic': cnicC.text.trim(),
        'address': addressC.text.trim(),
        'caseType': caseType,
        'note': noteC.text.trim(),
        'role': "client",
        'isApproved': false,
        'cnicFrontBase64': frontBase64,
        'cnicBackBase64': backBase64,
        'frontName': frontName,
        'backName': backName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Client Registered! Pending Approval")));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget buildField(TextEditingController c, String label,
      {bool obscure = false,
      String? Function(String?)? validator,
      void Function(String)? onChanged,
      InputDecoration? decoration}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: decoration ??
            InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white),
              enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green)),
            ),
      ),
    );
  }

  Widget buildProgressBar() {
    final steps = [
      {"icon": Icons.person, "desc": "Account"},
      {"icon": Icons.credit_card, "desc": "CNIC"},
      {"icon": Icons.phone, "desc": "Contact"},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          int stepIndex = index ~/ 2;
          bool isActive = stepIndex == currentStep;
          bool isCompleted = stepIndex < currentStep;

          Color circleColor = isCompleted
              ? Colors.green
              : isActive
                  ? Colors.amber
                  : Colors.grey.shade600;

          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: circleColor,
                  child: Icon(
                    steps[stepIndex]["icon"] as IconData,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[stepIndex]["desc"] as String,
                  style: TextStyle(
                    color: circleColor,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else {
          int leftStep = (index - 1) ~/ 2;
          Color lineColor =
              leftStep < currentStep ? Colors.green : Colors.grey.shade600;
          return SizedBox(
            width: 30,
            child: Divider(
              color: lineColor,
              thickness: 3,
              height: 40,
            ),
          );
        }
      }),
    );
  }

  Widget stepContent() {
    switch (currentStep) {
      case 0:
        return Column(
          children: [
            buildField(nameC, "Full Name",
                validator: (v) => v!.isEmpty ? "Required" : null),
            buildField(emailC, "Email",
                validator: (v) => !v!.contains("@") ? "Invalid" : null),
            buildField(
              passC,
              "Password",
              obscure: true,
              validator: (v) {
                if (v == null || v.isEmpty) return "Required";
                if (!isPasswordValid(v)) {
                  return "Min 8 chars, include number & special char";
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: "Password",
                hintText:
                    "At least 8 chars, include number & special character",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green)),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            buildField(cnicC, "CNIC",
                validator: (v) => v!.length != 15 ? "Invalid" : null,
                onChanged: (v) {
                  cnicC.text = formatCNIC(v);
                  cnicC.selection = TextSelection.fromPosition(
                      TextPosition(offset: cnicC.text.length));
                }),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: pickFront,
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      cnicFront != null ? Colors.green : Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(
                frontName == null
                    ? "Upload CNIC Front"
                    : "Front Selected: $frontName",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: pickBack,
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      cnicBack != null ? Colors.green : Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(
                backName == null
                    ? "Upload CNIC Back"
                    : "Back Selected: $backName",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            buildField(phoneC, "Phone", validator: (v) {
              if (!v!.startsWith("+92")) return "Must start with +92";
              if (v.length != 13) return "Invalid";
              return null;
            }, onChanged: (v) {
              phoneC.text = formatPhone(v);
              phoneC.selection = TextSelection.fromPosition(
                  TextPosition(offset: phoneC.text.length));
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: caseType,
              dropdownColor: Colors.black,
              decoration: const InputDecoration(
                labelText: "Case Type",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green)),
              ),
              items: caseTypes
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => caseType = v),
              validator: (v) => v == null ? "Required" : null,
            ),
            const SizedBox(height: 12),
            buildField(addressC, "Address",
                validator: (v) => v!.isEmpty ? "Required" : null),
            buildField(noteC, "Notes (optional)"),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Register as Client")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              buildProgressBar(),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: stepContent(),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentStep > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          currentStep--;
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text("Back"),
                    )
                  else
                    const SizedBox(width: 90),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!validateStep(currentStep)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please fill all required fields correctly.")),
                        );
                        return;
                      }
                      if (currentStep < 2) {
                        setState(() {
                          currentStep++;
                        });
                      } else {
                        registerClient();
                      }
                    },
                    icon: Icon(
                        currentStep == 2 ? Icons.check : Icons.arrow_forward),
                    label: Text(currentStep == 2 ? "Submit" : "Next"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
