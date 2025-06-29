import 'package:contacts/contacts_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import './firebase_options.dart';
import 'pages/user_profile.dart';
import 'pages/contacts_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox<Map>('contact_data');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

const _interTextTheme = TextTheme(
  displayLarge: TextStyle(fontFamily: 'Inter'),
  displayMedium: TextStyle(fontFamily: 'Inter'),
  displaySmall: TextStyle(fontFamily: 'Inter'),
  headlineLarge: TextStyle(fontFamily: 'Inter'),
  headlineMedium: TextStyle(fontFamily: 'Inter'),
  headlineSmall: TextStyle(fontFamily: 'Inter'),
  titleLarge: TextStyle(fontFamily: 'Inter'),
  titleMedium: TextStyle(fontFamily: 'Inter'),
  titleSmall: TextStyle(fontFamily: 'Inter'),
  bodyLarge: TextStyle(fontFamily: 'Inter'),
  bodyMedium: TextStyle(fontFamily: 'Inter'),
  bodySmall: TextStyle(fontFamily: 'Inter'),
  labelLarge: TextStyle(fontFamily: 'Inter'),
  labelMedium: TextStyle(fontFamily: 'Inter'),
  labelSmall: TextStyle(fontFamily: 'Inter'),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureProvider<ContactsController?>(
      create: (context) => ContactsController.create(),
      initialData: null,
      child: MaterialApp(
        title: 'Contacts',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.cyan,
            brightness: Brightness.dark,
          ),
          fontFamily: 'Inter',
          textTheme: _interTextTheme,
          useMaterial3: true,
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          fontFamily: 'Inter',
          textTheme: _interTextTheme,
          useMaterial3: true,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedPage = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactsController?>(
      builder: (context, controller, child) {
        // Show loading while controller is being created
        if (controller == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing contacts...'),
                ],
              ),
            ),
          );
        }

        // Controller is ready, show the main app
        final List<Widget> pages = [
          const ContactsPage(),
          const UserProfile(),
        ];

        return Scaffold(
          body: pages[selectedPage],
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Contacts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: selectedPage,
            onTap: (int index) {
              setState(() {
                selectedPage = index;
              });
            },
          ),
        );
      },
    );
  }
}
