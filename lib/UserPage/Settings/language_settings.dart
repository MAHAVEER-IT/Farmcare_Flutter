import 'package:farmcare/utils/app_localizations.dart';
import 'package:farmcare/utils/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';


class LanguageSettings extends StatefulWidget {
  const LanguageSettings({Key? key}) : super(key: key);

  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.translate(
            'selectLanguage', languageProvider.currentLanguage)),
        backgroundColor: Colors.green.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.translate(
                  'selectLanguage', languageProvider.currentLanguage),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildLanguageOption('English', 'English'),
            _buildLanguageOption('தமிழ்', 'Tamil'),
            _buildLanguageOption('हिंदी', 'Hindi'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String displayName, String value) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: RadioListTile<String>(
        title: Text(displayName),
        value: value,
        groupValue: languageProvider.currentLanguage,
        onChanged: (String? value) {
          if (value != null) {
            languageProvider.setLanguage(value);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${AppLocalizations.translate('languageChanged', value)} $displayName'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        activeColor: Colors.green.shade800,
      ),
    );
  }
}
