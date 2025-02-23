import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/globals/globals.dart';
import 'package:formgenie/pages/history_page.dart';
import 'pages/chat_page.dart';
import 'pages/preview_page.dart';
import 'pages/editor_page.dart';
import 'pages/export_page.dart';
import 'widgets/sidebar.dart';
import 'package:provider/provider.dart';
import 'providers/form_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'pages/analytics_page.dart';
import 'pages/responses_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Create providers outside of the widget tree
  final formProvider = FormProvider();
  final authProvider = AuthProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FormProvider>.value(value: formProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const Key('material_app'), // Add a key
      debugShowCheckedModeBanner: false,
      title: 'FormGenie',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark().copyWith(
          primary: const Color(0xFF8B5CF6),
          background: const Color(0xFF1E1E1E),
        ),
      ),
      home: const FormGenieApp(),
    );
  }
}

class FormGenieApp extends StatefulWidget {
  const FormGenieApp({super.key});

  @override
  State<FormGenieApp> createState() => _FormGenieAppState();
}

class _FormGenieAppState extends State<FormGenieApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Use the Sidebar widget here
          Sidebar(
            selectedIndex: Globals.selectedIndex,
            onIndexChanged: (index) {
              setState(() {
                Globals.selectedIndex = index;
              });
            },
            onFormIdChanged: (formId) {
              setState(() {
                Globals.setCurrentFormFirestoreId(formId);
              });
            },
          ),
          // Main Content
          Expanded(
            child: _buildPage(Globals.selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return ChatPage(
          onIndexChanged: (index) {
            setState(() {
              Globals.selectedIndex = index;
            });
          },
          onFormIdChanged: (formId) {
            setState(() {
              Globals.setCurrentFormFirestoreId(formId);
            });
          },
        );
      case 1:
        return EditorPage(
          onIndexChanged: (index) {
            setState(() {
              Globals.selectedIndex = index;
            });
          },
        );
      case 2:
        return PreviewPage(
          onIndexChanged: (index) {
            setState(() {
              Globals.selectedIndex = index;
            });
          },
        );
      case 3:
        return ExportPage();
      case 4:
        return HistoryPage(
          onIndexChanged: (index) {
            setState(() {
              Globals.selectedIndex = index;
            });
          },
          onFormIdChanged: (formId) {
            setState(() {
              Globals.setCurrentFormFirestoreId(formId);
            });
          },
        );
      case 5:
        return const AnalyticsPage();
      case 6:
        return const ResponsesPage();
      default:
        return Container();
    }
  }
}
