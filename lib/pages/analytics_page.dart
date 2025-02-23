import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/providers/form_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'dart:convert';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  List<Map<String, String>> _insights = [];
  List<Map<String, String>> _actionItems = [];
  List<Map<String, dynamic>> _mcqQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final formProvider = Provider.of<FormProvider>(context, listen: false);
    final formId = formProvider.formId;

    try {
      // Fetch form data to get questions
      final formResponse = await http.get(
        Uri.parse('YOUR_API_URL_HERE/forms/$formId'),
      );

      // Fetch responses
      final responsesResponse = await http.get(
        Uri.parse('YOUR_API_URL_HERE/forms/$formId/responses'),
      );

      // Fetch analysis
      final analysisResponse = await http.get(
        Uri.parse('YOUR_API_URL_HERE/forms/analyze/$formId?type=analysis'),
      );

      // Fetch action items
      final suggestionsResponse = await http.get(
        Uri.parse('YOUR_API_URL_HERE/forms/analyze/$formId?type=suggestions'),
      );

      if (formResponse.statusCode == 200 &&
          responsesResponse.statusCode == 200 &&
          analysisResponse.statusCode == 200 &&
          suggestionsResponse.statusCode == 200) {
        // Parse form data
        final formData = jsonDecode(formResponse.body);
        final responsesData = jsonDecode(responsesResponse.body);
        var analysisData = jsonDecode(analysisResponse.body);
        var suggestionsData = jsonDecode(suggestionsResponse.body);

        // Handle the case where the data might be a string that needs another decode
        if (analysisData is String) {
          try {
            analysisData = jsonDecode(analysisData);
          } catch (e) {
            debugPrint("Analysis JSON decode error: $e");
          }
        }

        if (suggestionsData is String) {
          try {
            suggestionsData = jsonDecode(suggestionsData);
          } catch (e) {
            debugPrint("Suggestions JSON decode error: $e");
          }
        }

        // Extract analysis data
        List<Map<String, String>> insights = [];
        if (analysisData is Map<String, dynamic> &&
            analysisData['analysis'] != null) {
          final analysis = analysisData['analysis'];
          if (analysis is List) {
            insights = analysis
                .map((item) => {
                      'title': item['title']?.toString() ?? '',
                      'description': item['description']?.toString() ?? '',
                    })
                .toList();
          }
        }

        // Extract suggestions data
        List<Map<String, String>> actionItems = [];
        if (suggestionsData is Map<String, dynamic> &&
            suggestionsData['actionPoints'] != null) {
          final actionPoints = suggestionsData['actionPoints'];
          if (actionPoints is List) {
            actionItems = actionPoints
                .map((item) => {
                      'title': item['title']?.toString() ?? '',
                      'description': item['description']?.toString() ?? '',
                      'reasoning': item['reasoning']?.toString() ?? '',
                    })
                .toList();
          }
        }

        // Process MCQ questions and their responses
        final items = formData['items'] as List? ?? [];
        final responses = responsesData['responses'] as List? ?? [];
        List<Map<String, dynamic>> mcqQuestions = [];

        for (var item in items) {
          final question = item['questionItem']['question'];
          final questionId = question['questionId'];

          // Check if it's an MCQ question (radio or checkbox)
          if (question['choiceQuestion'] != null) {
            final options = question['choiceQuestion']['options'] as List;
            Map<String, int> optionCounts = {};

            // Initialize counts
            for (var option in options) {
              optionCounts[option['value']] = 0;
            }

            // Count responses
            for (var response in responses) {
              final answers = response['answers'][questionId]?['textAnswers']
                  ?['answers'] as List?;
              if (answers != null) {
                for (var answer in answers) {
                  final value = answer['value'];
                  optionCounts[value] = (optionCounts[value] ?? 0) + 1;
                }
              }
            }

            // Calculate percentages
            final totalResponses = responses.length;
            List<_BarData> barData = optionCounts.entries.map((entry) {
              final percentage = totalResponses > 0
                  ? (entry.value / totalResponses).toDouble()
                  : 0.0;
              return _BarData(
                entry.key,
                percentage,
                '${(percentage * 100).round()}%',
              );
            }).toList();

            mcqQuestions.add({
              'title': item['title'],
              'type': question['choiceQuestion']['type'],
              'barData': barData,
            });
          }
        }

        setState(() {
          _insights = insights;
          _actionItems = actionItems;
          _mcqQuestions = mcqQuestions;
          _isLoading = false;
        });
      } else {
        throw 'Error fetching analytics data';
      }
    } catch (e) {
      debugPrint("API Exception: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildShimmerInsight() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
                        'Response Analytics',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI-powered insights from your form responses',
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
                          'Export Report',
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
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'New Analysis',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
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
              _isLoading
                  ? Row(
                      children: [
                        Expanded(child: _buildShimmerCard()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildShimmerCard()),
                      ],
                    )
                  : _mcqQuestions.isEmpty
                      ? const Center(
                          child: Text(
                            'No MCQ questions found in the form',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        )
                      : IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_mcqQuestions.length == 1)
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    _mcqQuestions[0]['title'],
                                    _mcqQuestions[0]['barData'],
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    _mcqQuestions[0]['title'],
                                    _mcqQuestions[0]['barData'],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    _mcqQuestions[1]['title'],
                                    _mcqQuestions[1]['barData'],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI-Generated Insights',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? Column(
                          children: List.generate(
                            3,
                            (index) => _buildShimmerInsight(),
                          ),
                        )
                      : Column(
                          children: _insights
                              .map((insight) =>
                                  _buildInsightCard(insight['title']!))
                              .toList(),
                        ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Action Items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? Column(
                          children: List.generate(
                            3,
                            (index) => _buildShimmerInsight(),
                          ),
                        )
                      : Column(
                          children: _actionItems
                              .map((item) =>
                                  _buildActionItemCard(item['title']!))
                              .toList(),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, List<_BarData> data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ...data.map((item) => _buildBar(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildBar(_BarData data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                data.percentage,
                style: const TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              // Background (empty portion)
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF2A2A2A),
                ),
              ),
              // Filled portion
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: data.value,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            FontAwesomeIcons.bolt,
            color: Color(0xFF8B5CF6),
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            FontAwesomeIcons.checkCircle,
            color: Color(0xFF8B5CF6),
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  final String label;
  final double value;
  final String percentage;

  _BarData(this.label, this.value, this.percentage);
}
