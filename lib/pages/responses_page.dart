import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/providers/form_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'dart:convert';

class ResponsesPage extends StatelessWidget {
  const ResponsesPage({super.key});

  Future<FormWithResponses> _fetchFormData(String formId) async {
    try {
      final formResponse = await http.get(
        Uri.parse('YOUR_API_ENDPOINT/forms/$formId'),
      );

      final responsesResponse = await http.get(
        Uri.parse('YOUR_API_ENDPOINT/forms/$formId/responses'),
      );

      if (formResponse.statusCode == 200 &&
          responsesResponse.statusCode == 200) {
        final formData = jsonDecode(formResponse.body);
        final responsesData = jsonDecode(responsesResponse.body);
        return FormWithResponses(formData, responsesData);
      } else {
        throw 'Error fetching form data';
      }
    } catch (e) {
      debugPrint("API Exception: $e");
      throw 'Error: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          color: const Color(0xFF171616),
          padding: const EdgeInsets.fromLTRB(45, 50, 45, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Form Responses',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'View and manage responses to your form',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, color: Colors.white),
                        label: const Text(
                          'Export Responses',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A2A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Consumer<FormProvider>(
                builder: (context, formProvider, child) {
                  if (formProvider.formId.isEmpty) {
                    return const Text(
                      "No form selected",
                      style: TextStyle(color: Colors.white),
                    );
                  }

                  return FutureBuilder<FormWithResponses>(
                    future: _fetchFormData(formProvider.formId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Column(
                          children: List.generate(
                              3,
                              (index) => Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Shimmer.fromColors(
                                      baseColor: const Color(0xFF1E1E1E),
                                      highlightColor: const Color(0xFF2A2A2A),
                                      child: Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  )),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load responses\n${snapshot.error.toString()}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      final responses =
                          data.responses['responses'] as List? ?? [];

                      if (responses.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                FontAwesomeIcons.inbox,
                                color: Color(0xFF8B5CF6),
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No responses yet',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return _buildResponsesSection(data);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsesSection(FormWithResponses data) {
    final responses = data.responses['responses'] as List? ?? [];
    final items = data.form['items'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              data.form['info']['title'] ?? 'Form Responses',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${responses.length} Responses',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...responses
            .asMap()
            .entries
            .map((entry) =>
                _buildResponseCard(entry.value, items, entry.key + 1))
            .toList(),
      ],
    );
  }

  Widget _buildResponseCard(
      Map<String, dynamic> response, List<dynamic> items, int responseNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Response $responseNumber',
                style: const TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatTimestamp(response['createTime']),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final question = item['questionItem']['question'];
            final questionId = question['questionId'];
            final answer =
                response['answers'][questionId]?['textAnswers']?['answers'];
            return _buildAnswerItem(item['title'], answer);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAnswerItem(String questionTitle, List<dynamic>? answers) {
    if (answers == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          ...answers
              .map((answer) => Text(
                    answer['value'],
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}

class FormWithResponses {
  final Map<String, dynamic> form;
  final Map<String, dynamic> responses;

  FormWithResponses(this.form, this.responses);
}
