import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }
  await MobileAds.instance.initialize();
  runApp(const GSRTCSarthiApp());
}

class GSRTCSarthiApp extends StatelessWidget {
  const GSRTCSarthiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GSRTC સારથિ & મિત્ર',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorSchemeSeed: const Color(0xFF0D5C46),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const MasterAppRouter(),
    );
  }
}

class CompleteQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  CompleteQuestion({required this.question, required this.options, required this.correctIndex});

  Map<String, dynamic> toMap() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
  };

  factory CompleteQuestion.fromMap(Map<String, dynamic> map) => CompleteQuestion(
    question: map['question'] ?? '',
    options: List<String>.from(map['options'] ?? []),
    correctIndex: map['correctIndex'] ?? 0,
  );
}

class SpecialExamModel {
  final String id;
  final String title;
  final String targetRole;
  final int price;
  final int durationMinutes;
  final List<CompleteQuestion> questions;

  SpecialExamModel({
    required this.id,
    required this.title,
    required this.targetRole,
    required this.price,
    required this.durationMinutes,
    required this.questions,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'targetRole': targetRole,
    'price': price,
    'durationMinutes': durationMinutes,
    'questions': questions.map((q) => q.toMap()).toList(),
  };

  factory SpecialExamModel.fromMap(Map<String, dynamic> map, String docId) => SpecialExamModel(
    id: docId,
    title: map['title'] ?? '',
    targetRole: map['targetRole'] ?? '',
    price: map['price'] ?? 0,
    durationMinutes: map['durationMinutes'] ?? 60,
    questions: (map['questions'] as List<dynamic>?)
            ?.map((item) => CompleteQuestion.fromMap(Map<String, dynamic>.from(item)))
            .toList() ??
        [],
  );
}
