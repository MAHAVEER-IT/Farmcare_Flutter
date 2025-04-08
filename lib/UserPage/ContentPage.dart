import 'package:farmcare/UserPage/Blog/Blog_UI.dart';
import 'package:farmcare/UserPage/bottom_nav.dart';
import 'package:farmcare/utils/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../AI_ChatBot/chatBot_page.dart';
import 'Vet_Vac/Vet_page.dart';

class UserContentPage extends StatefulWidget {
  const UserContentPage({super.key});

  @override
  State<UserContentPage> createState() => _UserContentPageState();
}

class _UserContentPageState extends State<UserContentPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    Blog(),
    ChatScreen(),
    PetVaccinationApp(),
  ];

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavBar(
          selectedIndex: _selectedIndex,
          onTabChange: _onTabChange,
        ),
      ),
    );
  }
}
