import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pending.dart';

class RegisterLawyer extends StatefulWidget {
  const RegisterLawyer({super.key});

  @override
  State<RegisterLawyer> createState() => _RegisterLawyerState();
}

class _RegisterLawyerState extends State<RegisterLawyer> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  int currentStep = 0;

  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passwordC = TextEditingController();

  final phoneC = TextEditingController(text: "+92");
  final cnicC = TextEditingController();
  Uint8List? cnicFrontBytes;
  Uint8List? cnicBackBytes;
  String? cnicFrontName;
  String? cnicBackName;

  final barCouncilCertNameC = TextEditingController();
  DateTime? registrationDate;
  Uint8List? barCouncilCertBytes;
  String? barCouncilCertFileName;

  final specializationC = TextEditingController();
  final experienceC = TextEditingController();
  final bioC = TextEditingController();

  String? selectedCity;

  List<String> cities = [
    "Karachi",
    "Lahore",
    "Islamabad",
    "Rawalpindi",
    "Peshawar",
    "Quetta",
    "Multan",
    "Faisalabad",
  ];

  bool isLoading = false;

  // PASSWORD VALIDATION
  bool isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[0-9])(?=.*[!@#\$&*~]).{8,}$');
    return regex.hasMatch(password);
  }

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

  Future<void> pickFile(Function(Uint8List, String) onPicked) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      onPicked(result.files.first.bytes!, result.files.first.name);
    }
  }

  Future<void> pickCNICFront() async {
    await pickFile((bytes, name) {
      setState(() {
        cnicFrontBytes = bytes;
        cnicFrontName = name;
      });
    });
  }

  Future<void> pickCNICBack() async {
    await pickFile((bytes, name) {
      setState(() {
        cnicBackBytes = bytes;
        cnicBackName = name;
      });
    });
  }

  Future<void> pickBarCouncilCert() async {
    await pickFile((bytes, name) {
      setState(() {
        barCouncilCertBytes = bytes;
        barCouncilCertFileName = name;
      });
    });
  }

  Future<void> pickRegistrationDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: registrationDate ?? now,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
    );
    if (selected != null) {
      setState(() {
        registrationDate = selected;
      });
    }
  }

  bool validateCurrentStep() {
    switch (currentStep) {
      case 0:
        if (nameC.text.trim().isEmpty) return false;
        if (!emailC.text.contains("@")) return false;
        if (!isPasswordValid(passwordC.text.trim())) return false;
        return true;
      case 1:
        if (!phoneC.text.startsWith("+92")) return false;
        if (phoneC.text.length != 13) return false;
        if (cnicC.text.length != 15) return false;
        if (cnicFrontBytes == null || cnicBackBytes == null) return false;
        return true;
      case 2:
        if (barCouncilCertNameC.text.trim().isEmpty) return false;
        if (registrationDate == null) return false;
        if (barCouncilCertBytes == null) return false;
        return true;
      case 3:
        if (specializationC.text.trim().isEmpty) return false;
        if (experienceC.text.trim().isEmpty) return false;
        if (selectedCity == null) return false;
        return true;
      default:
        return false;
    }
  }

  Future<void> registerLawyer() async {
    if (!_formKey.currentState!.validate() || !validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all required fields correctly!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _auth.createUserWithEmailAndPassword(
        email: emailC.text.trim(),
        password: passwordC.text.trim(),
      );

      String uid = user.user!.uid;

      await _firestore.collection('lawyers').doc(uid).set({
        'name': nameC.text.trim(),
        'email': emailC.text.trim(),
        'phone': phoneC.text.trim(),
        'cnic': cnicC.text.trim(),
        'specialization': specializationC.text.trim(),
        'experience': experienceC.text.trim(),
        'city': selectedCity,
        'bio': bioC.text.trim(),
        'certificateBase64': base64Encode(barCouncilCertBytes!),
        'certificateName': barCouncilCertFileName,
        'cnicFrontBase64': cnicFrontBytes != null ? base64Encode(cnicFrontBytes!) : null,
        'cnicBackBase64': cnicBackBytes != null ? base64Encode(cnicBackBytes!) : null,
        'isApproved': false,
        'role': 'lawyer',
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => isLoading = false);
  }

  Widget field(TextEditingController c, String label,
      {bool obscure = false,
      String? Function(String?)? validator,
      void Function(String)? onChanged,
      String? hintText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white60),
          labelStyle: const TextStyle(color: Colors.white),
          enabledBorder:
              const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          focusedBorder:
              const OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
        ),
      ),
    );
  }

  Widget buildProgressBar() {
    final steps = [
      {"label": "Account", "icon": Icons.person},
      {"label": "CNIC", "icon": Icons.badge},
      {"label": "Bar Council", "icon": Icons.school},
      {"label": "Details", "icon": Icons.work},
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
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[stepIndex]["label"] as String,
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
          Color lineColor = leftStep < currentStep ? Colors.green : Colors.grey.shade600;
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
            field(nameC, "Full Name", validator: (v) => v!.isEmpty ? "Required" : null),
            field(emailC, "Email", validator: (v) => !v!.contains("@") ? "Invalid email" : null),
            field(
              passwordC,
              "Password",
              obscure: true,
              validator: (v) {
                if (v == null || v.isEmpty) return "Required";
                if (!isPasswordValid(v)) {
                  return "Min 8 chars, include number & special char";
                }
                return null;
              },
              hintText: "At least 8 chars, include number & special character",
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            field(phoneC, "Phone (+92XXXXXXXXXX)",
                validator: (v) {
                  if (!v!.startsWith("+92")) return "Must start with +92";
                  if (v.length != 13) return "Must be 13 digits";
                  return null;
                },
                onChanged: (v) {
                  phoneC.text = formatPhone(v);
                  phoneC.selection =
                      TextSelection.fromPosition(TextPosition(offset: phoneC.text.length));
                }),
            field(cnicC, "CNIC (XXXXX-XXXXXXX-X)",
                validator: (v) => v!.length != 15 ? "Invalid CNIC" : null,
                onChanged: (v) {
                  cnicC.text = formatCNIC(v);
                  cnicC.selection =
                      TextSelection.fromPosition(TextPosition(offset: cnicC.text.length));
                }),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: pickCNICFront,
              style: ElevatedButton.styleFrom(
                  backgroundColor: cnicFrontBytes != null ? Colors.green : Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(
                cnicFrontName == null ? "Upload CNIC Front" : "Selected: $cnicFrontName",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: pickCNICBack,
              style: ElevatedButton.styleFrom(
                  backgroundColor: cnicBackBytes != null ? Colors.green : Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(
                cnicBackName == null ? "Upload CNIC Back" : "Selected: $cnicBackName",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            field(barCouncilCertNameC, "Bar Council Certificate Name",
                validator: (v) => v!.isEmpty ? "Required" : null),
            const SizedBox(height: 12),
            InkWell(
              onTap: pickRegistrationDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Registration Date",
                  labelStyle: const TextStyle(color: Colors.white),
                  enabledBorder:
                      const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  focusedBorder:
                      const OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                ),
                child: Text(
                  registrationDate == null
                      ? "Select Date"
                      : "${registrationDate!.year}-${registrationDate!.month.toString().padLeft(2, '0')}-${registrationDate!.day.toString().padLeft(2, '0')}",
                  style: TextStyle(
                      color: registrationDate == null ? Colors.grey.shade600 : Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: pickBarCouncilCert,
              style: ElevatedButton.styleFrom(
                  backgroundColor: barCouncilCertBytes != null ? Colors.green : Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 50)),
              child: Text(
                barCouncilCertFileName == null
                    ? "Upload Bar Council Certificate"
                    : "Selected: $barCouncilCertFileName",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            field(specializationC, "Specialization (Criminal / Family / Corporate)",
                validator: (v) => v!.isEmpty ? "Required" : null),
            field(experienceC, "Experience (Years)"),
            DropdownButtonFormField(
              value: selectedCity,
              dropdownColor: Colors.black,
              decoration: const InputDecoration(
                labelText: "City",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent)),
              ),
              items: cities
                  .map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city, style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedCity = v),
              validator: (v) => v == null ? "City required" : null,
            ),
            field(bioC, "Bio (Optional)"),
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
      appBar: AppBar(
        title: const Text("Register as Lawyer"),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              buildProgressBar(),
              const SizedBox(height: 20),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(child: stepContent()),
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
                      if (!validateCurrentStep()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please fill all required fields correctly.")),
                        );
                        return;
                      }
                      if (currentStep < 3) {
                        setState(() {
                          currentStep++;
                        });
                      } else {
                        registerLawyer();
                      }
                    },
                    icon: Icon(currentStep == 3 ? Icons.check : Icons.arrow_forward),
                    label: Text(currentStep == 3 ? "Submit" : "Next"),
                  )
                ],
              ),
              const SizedBox(height: 10),
              if (isLoading) const LinearProgressIndicator(color: Colors.greenAccent),
            ],
          ),
        ),
      ),
    );
  }
}
