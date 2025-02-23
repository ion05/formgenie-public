import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/globals/globals.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
// Import your form provider
import '../providers/form_provider.dart';

class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      padding: const EdgeInsets.fromLTRB(45, 50, 45, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Your Form',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a platform to export your form to',
            style: TextStyle(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 20,
            runSpacing: 25,
            children: [
              _ExportOption(
                icon:
                    const FaIcon(FontAwesomeIcons.google, color: Colors.white),
                title: 'Google Forms',
                description:
                    'Export your form to Google Forms and share it with your audience',
                buttonText: 'Export to Google Forms',
                onTap: () {},
              ),
              _ExportOption(
                icon: const FaIcon(FontAwesomeIcons.microsoft,
                    color: Colors.white),
                title: 'Microsoft Forms',
                description:
                    'Export your form to Microsoft Forms for seamless integration',
                buttonText: 'Export to Microsoft Forms',
                onTap: () {},
              ),
              _ExportOption(
                icon: Image.network(
                    'https://static-00.iconduck.com/assets.00/airtable-icon-2048x1714-lmut2gtf.png',
                    width: 24,
                    height: 24),
                title: 'Airtable Forms',
                description:
                    'Export as Airtable form for data analysis and sharing with others',
                buttonText: 'Export to Airtable',
                onTap: () {},
              ),
              _ExportOption(
                icon: const FaIcon(FontAwesomeIcons.envelope,
                    color: Colors.white),
                title: 'Email Contacts',
                description:
                    'Send an email to your Google Contacts asking them to fill out your form.',
                buttonText: 'Send Email',
                onTap: () {},
              ),
              _ExportOption(
                icon: const FaIcon(FontAwesomeIcons.fileCode,
                    color: Colors.white),
                title: 'JSON Format',
                description:
                    'Download your form data in JSON format for custom integration',
                buttonText: 'Download JSON',
                onTap: () {},
              ),
              _ExportOption(
                icon:
                    const FaIcon(FontAwesomeIcons.filePdf, color: Colors.white),
                title: 'PDF Form',
                description:
                    'Export as PDF form for offline use and sharing with others',
                buttonText: 'Download PDF',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportOption extends StatefulWidget {
  final Widget icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    this.onTap,
  });

  @override
  State<_ExportOption> createState() => _ExportOptionState();
}

class _ExportOptionState extends State<_ExportOption> {
  // Keep track of states for different export types
  final Map<String, Map<String, bool>> _states = {
    'Google Forms': {'loading': false, 'success': false, 'error': false},
    'Email Contacts': {
      'loading': false,
      'success': false,
      'error': false,
      'followupSent': false
    },
    // Add other export types as needed
  };

  void _updateState(String exportType,
      {bool? loading, bool? success, bool? error, bool? followupSent}) {
    if (!mounted) return;
    setState(() {
      if (loading != null) _states[exportType]!['loading'] = loading;
      if (success != null) _states[exportType]!['success'] = success;
      if (error != null) _states[exportType]!['error'] = error;
      if (followupSent != null)
        _states[exportType]!['followupSent'] = followupSent;
    });
  }

  Future<void> _exportToGoogleForms() async {
    if (_states['Google Forms']!['loading']!) return;

    _updateState('Google Forms', loading: true, success: false, error: false);

    final formProvider = context.read<FormProvider>();
    final formData = formProvider.getFormData();

    debugPrint(formData.toString());

    var headers = {'Content-Type': 'application/json'};
    var request =
        http.Request('POST', Uri.parse('YOUR_API_URL_HERE/forms/create'));
    request.body = json.encode({
      "email": FirebaseAuth.instance.currentUser?.email,
      "platform": "google",
      "formData": formData,
    });
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      debugPrint(response.statusCode.toString());

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        formProvider.formId = jsonResponse['formId'];
        formProvider.isExportedGoogle = true;
        formProvider.setFormExported(true);

        await FirebaseFirestore.instance
            .collection('forms')
            .doc(Globals.getCurrentFormFirestoreId())
            .update({
          'exportedGoogle': true,
          'formId': formProvider.formId,
          'isFormExported': true,
        });

        _updateState('Google Forms', loading: false, success: true);
        await launchUrl(Uri.parse(jsonResponse['formUrl']));
      } else {
        debugPrint(response.reasonPhrase);
        _updateState('Google Forms', loading: false, error: true);
      }
    } catch (e) {
      debugPrint(e.toString());
      _updateState('Google Forms', loading: false, error: true);
    }
  }

  Future<void> _sendEmailFirstTime() async {
    if (_states['Email Contacts']!['loading']!) return;

    _updateState('Email Contacts', loading: true, success: false, error: false);

    final formProvider = context.read<FormProvider>();

    var headers = {'Content-Type': 'application/json'};
    var request =
        http.Request('POST', Uri.parse('YOUR_API_URL_HERE/forms/send'));
    request.body = json.encode({
      "formId": formProvider.formId,
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    debugPrint(response.statusCode.toString());

    if (response.statusCode == 200) {
      await FirebaseFirestore.instance
          .collection('forms')
          .doc(Globals.getCurrentFormFirestoreId())
          .update({'emailSent': true});
      setState(() {
        formProvider.isEmailSent = true;
      });
      _updateState('Email Contacts', loading: false, success: true);
    } else {
      debugPrint(response.reasonPhrase);
      _updateState('Email Contacts', loading: false, error: true);
    }
  }

  Future<void> _sendEmailFollowUp() async {
    if (_states['Email Contacts']!['loading']!) return;

    _updateState('Email Contacts', loading: true, success: false, error: false);

    final formProvider = context.read<FormProvider>();

    var headers = {'Content-Type': 'application/json'};
    var request =
        http.Request('POST', Uri.parse('YOUR_API_URL_HERE/forms/followup'));
    request.body = json.encode({
      "formId": formProvider.formId,
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    debugPrint(response.statusCode.toString());

    if (response.statusCode == 200) {
      _updateState('Email Contacts',
          loading: false, success: true, followupSent: true);
    } else {
      debugPrint(response.reasonPhrase);
      _updateState('Email Contacts', loading: false, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = _states[widget.title] ??
        {'loading': false, 'success': false, 'error': false};
    final isLoading = states['loading']!;
    final isSuccess = states['success']!;
    final isError = states['error']!;
    final formProvider = context.watch<FormProvider>();

    // Special handling for Email Contacts button when email has been sent
    if (widget.title == 'Email Contacts' && formProvider.isEmailSent) {
      final isFollowupSent = states['followupSent'] ?? false;
      return Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.icon,
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: null, // Disabled
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(0, 48),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(8),
                          right: Radius.zero,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Email Sent',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendEmailFollowUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowupSent
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                      minimumSize: const Size(0, 48),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.zero,
                          right: Radius.circular(8),
                        ),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isFollowupSent
                                ? 'Follow-up Sent'
                                : 'Send Follow-up',
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Special handling for Google Forms button when form has been exported
    if (widget.title == 'Google Forms' && formProvider.isExportedGoogle) {
      return Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.icon,
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: null, // Disabled
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.green.withOpacity(0.5),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text(
                'Form Created',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // Default button rendering (unchanged)
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.icon,
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: TextStyle(
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.title == 'Google Forms'
                ? (isLoading ? null : _exportToGoogleForms)
                : widget.title == 'Email Contacts'
                    ? (isLoading ? null : _sendEmailFirstTime)
                    : widget.onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess
                  ? Colors.green
                  : isError
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isSuccess
                        ? 'Exported!'
                        : isError
                            ? 'Failed - Try Again'
                            : widget.buttonText,
                    style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
