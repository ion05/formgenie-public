import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/globals/globals.dart';
import 'package:formgenie/models/question.dart';
import 'dart:async';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  final Function(int) onIndexChanged;
  final Function(String) onFormIdChanged;
  const ChatPage(
      {super.key, required this.onIndexChanged, required this.onFormIdChanged});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isGenerating = false;
  bool _isAnalysisMode = false;
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    final formProvider = context.read<FormProvider>();
    if (formProvider.chatHistory.isEmpty) {
      setState(() {
        Future.delayed(Duration.zero, () {
          if (_isAnalysisMode) {
            _addBotMessage(
                'Hello! I\'m FormGenie. I can help you analyze your form responses. For example: "What is the average rating for question 3?" or "How many people selected option A in question 2?"');
          } else {
            _addBotMessage(Globals.getCurrentFormFirestoreId().isNotEmpty
                ? 'Hello! I\'m FormGenie. Tell me about the changes you want to make to the form. For example: "Modify question 3 to include this change"'
                : 'Hello! I\'m FormGenie. Tell me about the form you want to create. For example: "Create a dance class RSVP form"');
          }
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit({bool isAnalysis = false}) {
    if (_controller.text.trim().isEmpty || _isGenerating) return;

    final userMessage = _controller.text;
    _controller.clear();

    final formProvider = context.read<FormProvider>();
    formProvider.addChatMessage(ChatMessage(
      isUser: true,
      message: userMessage,
    ));

    // Add scroll to bottom after user message is added
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    if (isAnalysis) {
      _generateAnalysisResponse(userMessage);
    } else {
      _generateAIResponse(userMessage);
    }
  }

  void _generateAIResponse(String message) async {
    setState(() => _isGenerating = true);

    final formProvider = context.read<FormProvider>();
    final loadingMessageIndex = formProvider.chatHistory.length;
    formProvider.addChatMessage(ChatMessage(
      isUser: false,
      message: "...",
      animate: false,
      isNew: true,
    ));

    try {
      debugPrint(message);
      debugPrint(Globals.getCurrentFormFirestoreId());

      // Prepare request body based on whether we're updating or creating
      final Map<String, dynamic> requestBody;
      if (Globals.getCurrentFormFirestoreId().isNotEmpty) {
        final currentForm = formProvider.getFormData();
        final questions = formProvider.questions;
        final formattedData = {
          "info": {
            "title": currentForm['title'] ?? 'Untitled Form',
            "description": currentForm['description'] ?? '',
          },
          "items": questions.map((question) {
            final Map<String, dynamic> questionData = {
              "title": question.title,
              "description": question.description ?? '',
              "questionItem": {
                "question": {
                  "required": question.isRequired,
                }
              }
            };

            switch (question.type) {
              case 'text':
                questionData['questionItem']['question']
                    ['textQuestion'] = {"paragraph": false};
                break;
              case 'paragraph':
                questionData['questionItem']['question']
                    ['textQuestion'] = {"paragraph": true};
                break;
              case 'radio':
              case 'checkbox':
                questionData['questionItem']['question']['choiceQuestion'] = {
                  "type": question.type.toUpperCase(),
                  "options":
                      question.options.map((opt) => {"value": opt}).toList()
                };
                break;
              case 'scale':
                questionData['questionItem']['question']['scaleQuestion'] = {
                  "low": question.low,
                  "high": question.high,
                  "lowLabel": question.lowLabel,
                  "highLabel": question.highLabel
                };
                break;
            }
            return questionData;
          }).toList(),
        };
        requestBody = {
          'formData': formattedData,
          'prompt': message,
        };
      } else {
        requestBody = {'prompt': message};
      }

      // debugPrint("REQUEST BODY: ${requestBody.toString()}");

      final response = await http.post(
        Uri.parse(Globals.getCurrentFormFirestoreId().isNotEmpty
            ? 'YOUR_API_URL_HERE/forms/update-form'
            : 'YOUR_API_URL_HERE/forms/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final formData = jsonDecode(response.body);
        debugPrint("OUTPUT: ${formData.toString()}");

        // Handle different response formats based on whether we're updating or creating
        if (Globals.getCurrentFormFirestoreId().isNotEmpty) {
          // Handle update form response format
          if (formData['questions'] != null) {
            // Convert API questions to Question objects, excluding removed questions
            final questions = formData['questions']
                .where((q) => q['changeType'] != 'remove')
                .map((questionData) {
              String type;
              List<String>? options;
              int? low;
              int? high;
              String? lowLabel;
              String? highLabel;

              switch (questionData['type']) {
                case 'text':
                case 'paragraph':
                  type = questionData['type'];
                  break;
                case 'mcq':
                  type = 'checkbox';
                  options = List<String>.from(questionData['options']);
                  break;
                case 'radio':
                  type = 'radio';
                  options = List<String>.from(questionData['options']);
                  break;
                case 'rating':
                  type = 'scale';
                  final range = questionData['range'];
                  low = range[0];
                  high = range[1];
                  lowLabel = questionData['labels']['minLabel'];
                  highLabel = questionData['labels']['maxLabel'];
                  break;
                default:
                  type = 'text';
              }

              return Question(
                title: questionData['title'] ?? '',
                type: type,
                description: questionData['description'],
                isRequired: questionData['required'] ?? false,
                options: options,
                low: low ?? 1,
                high: high ?? 5,
                lowLabel: lowLabel ?? 'Not at all',
                highLabel: highLabel ?? 'Completely',
              );
            }).toList();

            // Update form provider with new data
            formProvider.updateForm(
              title: formData['title'] ?? 'Untitled Form',
              description: formData['description'] ?? '',
              questions: questions,
            );

            // Generate summary of changes
            final changes = formData['questions']
                .where((q) => q['change'] == true)
                .map((q) =>
                    '- ${q['changeType'] == 'remove' ? 'Removed' : 'Modified'}: "${q['title']}"')
                .join('\n');

            // Replace loading message with success message and form preview
            formProvider.replaceChatMessage(
              loadingMessageIndex,
              ChatMessage(
                isUser: false,
                message:
                    "I've updated the form with the following changes:\n$changes\n\nHere's the updated form:",
                formPreview: _generateFormPreview(formData),
                animate: true,
                isNew: true,
              ),
            );
          }
        } else {
          // Handle generate form response format (existing code)
          if (formData['formData'] != null &&
              formData['formData']['requests'] != null) {
            final requests = formData['formData']['requests'] as List;
            final formInfo = requests.firstWhere(
              (request) => request['updateFormInfo'] != null,
              orElse: () => null,
            )?['updateFormInfo']?['info'];

            // Convert API questions to Question objects
            final questions = requests
                .where((request) => request['createItem'] != null)
                .map((request) {
              final item = request['createItem']['item'];
              final questionData = item['questionItem']['question'];

              // Determine question type and options
              String type;
              List<String>? options;
              int? low;
              int? high;
              String? lowLabel;
              String? highLabel;
              if (questionData['textQuestion'] != null) {
                type = questionData['textQuestion']['paragraph']
                    ? 'paragraph'
                    : 'text';
              } else if (questionData['choiceQuestion'] != null) {
                final choiceQuestion = questionData['choiceQuestion'];
                type = choiceQuestion['type'].toLowerCase();
                options = (choiceQuestion['options'] as List)
                    .map((option) => option['value'] as String)
                    .toList();
              } else if (questionData['scaleQuestion'] != null) {
                type = 'scale';
                low = questionData['scaleQuestion']['low'];
                high = questionData['scaleQuestion']['high'];
                lowLabel = questionData['scaleQuestion']['lowLabel'];
                highLabel = questionData['scaleQuestion']['highLabel'];
              } else {
                type = 'text';
              }

              return Question(
                title: item['title'] ?? '',
                type: type,
                description: item['description'],
                isRequired: questionData['required'] ?? false,
                options: options,
                low: low ?? 1,
                high: high ?? 5,
                lowLabel: lowLabel ?? 'Not at all',
                highLabel: highLabel ?? 'Completely',
              );
            }).toList();

            // Update form provider with new data
            formProvider.updateForm(
              title: formInfo?['title'] ?? 'Untitled Form',
              description: formInfo?['description'] ?? '',
              questions: questions,
            );

            // Add form data to Firestore if this is a new form
            if (Globals.getCurrentFormFirestoreId().isEmpty) {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final formFirestoreId =
                      await FirebaseFirestore.instance.collection('forms').add({
                    'user': user.uid,
                    'title': formInfo?['title'] ?? 'Untitled Form',
                    'description': formInfo?['description'] ?? '',
                    'questions': questions.map((q) => q.toMap()).toList(),
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'exportedGoogle': false,
                    'emailSent': false,
                  });
                  await widget.onFormIdChanged(formFirestoreId.id.toString());
                }
              } catch (e) {
                debugPrint('Error saving to Firestore: $e');
              }
            }

            // Replace loading message with success message and form preview
            formProvider.replaceChatMessage(
              loadingMessageIndex,
              ChatMessage(
                isUser: false,
                message: Globals.getCurrentFormFirestoreId().isEmpty
                    ? "Here's a form based on your requirements:"
                    : "I've updated the form according to your changes:",
                formPreview: _generateFormPreview(formData),
                animate: true,
                isNew: true,
              ),
            );
          } else {
            // Handle case where formData structure is invalid
            formProvider.replaceChatMessage(
              loadingMessageIndex,
              ChatMessage(
                isUser: false,
                message:
                    "Sorry, I received an invalid response from the server. Please try again.",
                animate: true,
                isNew: true,
              ),
            );
          }
        }

        setState(() {});
      } else {
        debugPrint(response.body);
        // Replace loading message with error message
        formProvider.replaceChatMessage(
          loadingMessageIndex,
          ChatMessage(
            isUser: false,
            message:
                "Sorry, I encountered an error while generating the form. Please try again.",
            animate: true,
            isNew: true,
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      // Replace loading message with error message
      formProvider.replaceChatMessage(
        loadingMessageIndex,
        ChatMessage(
          isUser: false,
          message:
              "Sorry, there was an error connecting to the server. Please try again.",
          animate: true,
          isNew: true,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);

      await Future.delayed(const Duration(milliseconds: 100));
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _generateAnalysisResponse(String message) async {
    setState(() => _isGenerating = true);

    final formProvider = context.read<FormProvider>();
    final loadingMessageIndex = formProvider.chatHistory.length;
    formProvider.addChatMessage(ChatMessage(
      isUser: false,
      message: "...",
      animate: false,
      isNew: true,
    ));

    try {
      debugPrint("message: $message formId: ${formProvider.formId}");
      final response = await http.get(
        Uri.parse(
            'YOUR_API_URL_HERE/forms/analyze-chat/${formProvider.formId}?prompt=${Uri.encodeComponent(message)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        debugPrint("Raw response: $responseBody");

        // First try to decode the response body
        dynamic decodedData;
        try {
          decodedData = jsonDecode(responseBody);
        } catch (e) {
          debugPrint("Initial JSON decode error: $e");
          throw Exception("Invalid response format");
        }

        // Handle the case where the data might be a string that needs another decode
        if (decodedData is String) {
          try {
            decodedData = jsonDecode(decodedData);
          } catch (e) {
            debugPrint("Secondary JSON decode error: $e");
            // If it fails to decode again, use the string as is
          }
        }

        // Now extract the answer
        String answerText;
        if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('data')) {
            final data = decodedData['data'];
            if (data is Map<String, dynamic>) {
              answerText =
                  data['answer']?.toString() ?? "No answer found in response";
            } else if (data is String) {
              // Try to decode the data string if it's JSON
              try {
                final dataMap = jsonDecode(data) as Map<String, dynamic>;
                answerText = dataMap['answer']?.toString() ??
                    "No answer found in response";
              } catch (e) {
                answerText = data;
              }
            } else {
              answerText = data?.toString() ?? "No answer found in response";
            }
          } else {
            answerText = decodedData['answer']?.toString() ??
                "No answer found in response";
          }
        } else {
          answerText = decodedData?.toString() ?? "Unexpected response format";
        }

        debugPrint("Final answer text: $answerText");

        formProvider.replaceChatMessage(
          loadingMessageIndex,
          ChatMessage(
            isUser: false,
            message: answerText,
            animate: true,
            isNew: true,
          ),
        );
      } else {
        debugPrint("Error response: ${response.body}");
        formProvider.replaceChatMessage(
          loadingMessageIndex,
          ChatMessage(
            isUser: false,
            message:
                "Sorry, I encountered an error while analyzing the form. Please try again.",
            animate: true,
            isNew: true,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Error: $e");
      debugPrint("Stack trace: $stackTrace");
      formProvider.replaceChatMessage(
        loadingMessageIndex,
        ChatMessage(
          isUser: false,
          message:
              "Sorry, there was an error connecting to the server. Please try again.",
          animate: true,
          isNew: true,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
      await Future.delayed(const Duration(milliseconds: 100));
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addBotMessage(String message,
      {bool withFormPreview = false, Map<String, dynamic>? formData}) {
    final formProvider = context.read<FormProvider>();
    formProvider.addChatMessage(ChatMessage(
      isUser: false,
      message: message,
      formPreview: withFormPreview ? _generateFormPreview(formData) : null,
      animate: true,
      isNew: true,
    ));
  }

  Widget _generateFormPreview(Map<String, dynamic>? formData) {
    if (formData == null) return const SizedBox.shrink();

    // Handle update form format
    if (formData['questions'] != null) {
      final questions =
          formData['questions'].where((q) => q['changeType'] != 'remove');

      return Container(
        margin: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var question in questions)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3F3F3F),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['title'] ?? 'Untitled Question',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${_getDisplayQuestionType(question)}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (question['description']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        question['description'],
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (question['options'] != null) ...[
                      const SizedBox(height: 12),
                      ..._buildOptionsForUpdate(question),
                    ],
                    if (question['type'] == 'rating') ...[
                      const SizedBox(height: 12),
                      _buildScaleForUpdate(question),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // Handle generate form format (existing code)
    final requests = formData['formData']?['requests'] as List?;
    if (requests == null) return const SizedBox.shrink();

    // Extract title and description from updateFormInfo
    final formInfo = requests.firstWhere(
      (request) => request['updateFormInfo'] != null,
      orElse: () => null,
    )?['updateFormInfo']?['info'];

    // Extract questions from createItem requests
    final questions = requests
        .where((request) => request['createItem'] != null)
        .map((request) => request['createItem']['item'])
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Questions
          for (var question in questions)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3F3F3F),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question['title'] ?? 'Untitled Question',
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${_getDisplayQuestionType(question)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  if (question['description']?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      question['description'],
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                  // Display options for choice questions
                  if (_hasOptions(question)) ...[
                    const SizedBox(height: 12),
                    ..._buildOptions(question),
                  ],

                  // Display scale question
                  if (_hasScale(question)) ...[
                    const SizedBox(height: 12),
                    _buildScale(question),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            '🚀 Your AI-generated form is ready! 🎉\n\nI\'ve crafted this form just for you—ready to be reviewed, tweaked, and exported to your favorite forms app. If you\'d like any changes, just say "Modify question 3 to include this change" and I\'ll handle it in a snap! ⚡💡\n\nLet me know how I can make it even better! 😃✨',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Segoe UI Emoji',
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to editor page (index 1)
                  widget.onIndexChanged(1);
                },
                icon: const Icon(FontAwesomeIcons.pencil,
                    size: 16, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                label: const Text(
                  'Edit Form',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to preview page (index 2)
                  widget.onIndexChanged(2);
                },
                icon: const Icon(FontAwesomeIcons.eye,
                    size: 16, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                label: const Text(
                  'Preview Form',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to export page (index 3)
                  widget.onIndexChanged(3);
                },
                icon: const Icon(FontAwesomeIcons.shareNodes,
                    size: 16, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF248636),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                label: const Text(
                  'Export Form',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getDisplayQuestionType(Map<String, dynamic> question) {
    switch (question['type']) {
      case 'text':
        return 'Short Answer';
      case 'paragraph':
        return 'Long Answer';
      case 'mcq':
        return 'Multiple Choice';
      case 'radio':
        return 'Single Choice';
      case 'rating':
        return 'Scale';
      default:
        return 'Text';
    }
  }

  bool _hasOptions(Map<String, dynamic> question) {
    return question['questionItem']?['question']?['choiceQuestion']
            ?['options'] !=
        null;
  }

  bool _hasScale(Map<String, dynamic> question) {
    return question['questionItem']?['question']?['scaleQuestion'] != null;
  }

  List<Widget> _buildOptions(Map<String, dynamic> question) {
    final options = question['questionItem']?['question']?['choiceQuestion']
        ?['options'] as List?;
    if (options == null) return [];

    final questionType =
        question['questionItem']?['question']?['choiceQuestion']?['type'];
    final isRadio = questionType == 'RADIO';

    return options
        .map((option) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF3F3F3F),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRadio
                        ? Icons.radio_button_off
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option['value'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Widget _buildScale(Map<String, dynamic> question) {
    final scale = question['questionItem']?['question']?['scaleQuestion'];
    final low = scale?['low'];
    final high = scale?['high'];
    final lowLabel = scale?['lowLabel'];
    final highLabel = scale?['highLabel'];

    // create a row of radio buttons of the count of the scale
    final radioButtons = List.generate(
      high - low + 1,
      (index) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          Icons.radio_button_off,
          size: 18,
          color: const Color(0xFF8B5CF6),
        ),
      ),
    );

    return Row(
      children: [
        Text(
          lowLabel,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        ...radioButtons,
        Text(
          highLabel,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOptionsForUpdate(Map<String, dynamic> question) {
    final options = question['options'] as List?;
    if (options == null) return [];

    final isRadio = question['type'] == 'radio';

    return options
        .map((option) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF3F3F3F),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRadio
                        ? Icons.radio_button_off
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }

  Widget _buildScaleForUpdate(Map<String, dynamic> question) {
    final range = question['range'] as List;
    final labels = question['labels'] as Map<String, dynamic>;
    final low = range[0];
    final high = range[1];
    final lowLabel = labels['minLabel'];
    final highLabel = labels['maxLabel'];

    final radioButtons = List.generate(
      high - low + 1,
      (index) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          Icons.radio_button_off,
          size: 18,
          color: const Color(0xFF8B5CF6),
        ),
      ),
    );

    return Row(
      children: [
        Text(
          lowLabel,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        ...radioButtons,
        Text(
          highLabel,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formProvider = context.read<FormProvider>();

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF171616),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Globals.getCurrentFormFirestoreId() == ''
                            ? const Text(
                                'Form Generation Chat',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              )
                            : RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Form Generation Chat for ',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: formProvider.formTitle,
                                      style: const TextStyle(
                                          color: Color(0xFF8B5CF6)),
                                    ),
                                  ],
                                ),
                              ),
                        const SizedBox(height: 8),
                        Text(
                          'Describe the form you want to create and I\'ll help you generate it.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Consumer<FormProvider>(
                        builder: (context, formProvider, child) {
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: formProvider.chatHistory.length,
                            addAutomaticKeepAlives: true,
                            itemBuilder: (context, index) {
                              final message = formProvider.chatHistory[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _ChatMessage(
                                  isUser: message.isUser,
                                  message: message.message,
                                  formPreview: message.formPreview,
                                  animate: message.animate,
                                  isNew: message.isNew,
                                  hasBeenShown: message.hasBeenShown,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  _buildInputArea(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final formProvider = context.read<FormProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 18, 40, 30),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isAnalysisMode
                    ? 'Ask about your form responses...'
                    : 'Type your message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSubmit(isAnalysis: _isAnalysisMode),
            ),
          ),
          const SizedBox(width: 12),
          // Analysis button (only shown when form is exported)
          if (formProvider.isExportedGoogle) ...[
            ElevatedButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () {
                      setState(() {
                        _isAnalysisMode = !_isAnalysisMode;
                        // Clear chat history and add new welcome message
                        final formProvider = context.read<FormProvider>();
                        formProvider.clearChatHistory();
                        _addBotMessage(_isAnalysisMode
                            ? 'Hello! I\'m FormGenie. I can help you analyze your form responses. For example: "What is the average rating for question 3?" or "How many people selected option A in question 2?"'
                            : Globals.getCurrentFormFirestoreId().isNotEmpty
                                ? 'Hello! I\'m FormGenie. Tell me about the changes you want to make to the form. For example: "Modify question 3 to include this change"'
                                : 'Hello! I\'m FormGenie. Tell me about the form you want to create. For example: "Create a dance class RSVP form"');
                      });
                    },
              icon: Icon(FontAwesomeIcons.chartSimple,
                  color: _isAnalysisMode ? Colors.yellow : Colors.white,
                  size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAnalysisMode
                    ? Colors.yellow.withOpacity(0.2)
                    : const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 22,
                ),
              ),
              label: Text(
                'Analyze',
                style: TextStyle(
                    color: _isAnalysisMode ? Colors.yellow : Colors.white),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Send button
          GestureDetector(
            onTap: _isGenerating
                ? null
                : () => _handleSubmit(isAnalysis: _isAnalysisMode),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isGenerating
                    ? const Color(0xFF8B5CF6).withOpacity(0.5)
                    : const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}

class _ChatMessage extends StatefulWidget {
  final bool isUser;
  final String message;
  final bool animate;
  final Widget? formPreview;
  final bool isNew;
  final bool hasBeenShown;

  const _ChatMessage({
    required this.isUser,
    required this.message,
    this.animate = false,
    this.formPreview,
    this.isNew = true,
    this.hasBeenShown = false,
  });

  @override
  State<_ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<_ChatMessage>
    with AutomaticKeepAliveClientMixin {
  String _displayedText = '';
  Timer? _timer;
  bool _isAnimationComplete = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!widget.isUser &&
        widget.animate &&
        widget.isNew &&
        !widget.hasBeenShown) {
      if (!mounted) return;
      _startTypingAnimation();
    } else {
      setState(() {
        _displayedText = widget.message;
        _isAnimationComplete = true;
      });
    }
  }

  @override
  void didUpdateWidget(_ChatMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      setState(() {
        if (widget.animate && widget.isNew && !widget.hasBeenShown) {
          _displayedText = '';
          _isAnimationComplete = false;
          _startTypingAnimation();
        } else {
          _displayedText = widget.message;
          _isAnimationComplete = true;
        }
      });
    }
  }

  void _startTypingAnimation() {
    var currentIndex = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (currentIndex < widget.message.length) {
        setState(() {
          _displayedText = widget.message.substring(0, currentIndex + 1);
        });
        currentIndex++;
      } else {
        _isAnimationComplete = true;
        // Mark the message as shown when animation completes
        final formProvider = context.read<FormProvider>();
        formProvider.updateMessageAsShown(formProvider.chatHistory.indexWhere(
            (msg) =>
                msg.message == widget.message && msg.isUser == widget.isUser));
        timer.cancel();
      }
    });
  }

  Widget _buildLoadingIndicator() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[500]!,
      highlightColor: Colors.grey[300]!,
      child: const Text(
        "...",
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Row(
      mainAxisAlignment:
          widget.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isUser) _BotAvatar(),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            margin: (!widget.isUser)
                ? const EdgeInsets.fromLTRB(0, 0, 300, 0)
                : const EdgeInsets.fromLTRB(100, 16, 16, 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isUser
                  ? const Color(0xFF8B5CF6).withOpacity(0.2)
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.message == "..."
                    ? _buildLoadingIndicator()
                    : Text(
                        _displayedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                if (widget.formPreview != null) widget.formPreview!,
              ],
            ),
          ),
        ),
        if (widget.isUser)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                  FirebaseAuth.instance.currentUser?.photoURL ??
                      'https://avatars.githubusercontent.com/u/46714636?v=4'),
            ),
          ),
        if (widget.isUser) const SizedBox(width: 44),
      ],
    );
  }
}

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String value;

  const _FormField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
