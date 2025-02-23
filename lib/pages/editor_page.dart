import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/globals/globals.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';
import '../models/question.dart';

class EditorPage extends StatefulWidget {
  final Function(int) onIndexChanged;

  const EditorPage({super.key, required this.onIndexChanged});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final List<Question> questions = [];
  final List<String> questionTypes = ['text', 'radio', 'paragraph', 'checkbox', 'scale'];
  String formTitle = 'RSVP Form for Dance Class';
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formProvider = Provider.of<FormProvider>(context, listen: false);
      setState(() {
        questions.addAll(formProvider.questions.cast<Question>());
        formTitle = formProvider.formTitle;
      });
    });
  }

  Future<void> _addNewQuestion() async {
    setState(() {
      questions.add(Question(
        title: 'New Question',
        type: 'Short Answer',
      ));
    });
    await Future.delayed(const Duration(milliseconds: 100));
    scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _deleteQuestion(int index) {
    setState(() {
      questions.removeAt(index);
    });
  }

  void _updateQuestionTitle(int index, String newTitle) {
    setState(() {
      questions[index].title = newTitle;
    });
  }

  void _updateQuestionType(int index, String newType) {
    setState(() {
      questions[index].type = newType;
      // Clear options if switching to a non-choice type
      if (newType == 'Short Answer' || newType == 'Paragraph') {
        questions[index].options.clear();
      }
      // Add default option if switching to a choice type
      else if (newType == 'scale') {
        questions[index].minValue = 1;
        questions[index].maxValue = 5;
        questions[index].options.clear();
      } else if (questions[index].options.isEmpty) {
        questions[index].options.add('Option 1');
      }
    });
  }

  void _toggleRequired(int index) {
    setState(() {
      questions[index].isRequired = !questions[index].isRequired;
    });
  }

  void _addOption(int index) {
    setState(() {
      questions[index].options.add('New Option');
    });
  }

  void _updateOption(int questionIndex, int optionIndex, String newValue) {
    setState(() {
      questions[questionIndex].options[optionIndex] = newValue;
    });
  }

  void _deleteOption(int questionIndex, int optionIndex) {
    setState(() {
      questions[questionIndex].options.removeAt(optionIndex);
    });
  }

  void _updateFormTitle(String newTitle) {
    setState(() {
      formTitle = newTitle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF171616),
      padding: const EdgeInsets.fromLTRB(45, 40, 45, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              title: const Text(
                                'Edit Form Title',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: TextFormField(
                                initialValue: formTitle,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter form title',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey[600]!),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF8B3DFF)),
                                  ),
                                ),
                                onChanged: _updateFormTitle,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Done',
                                    style: TextStyle(color: Color(0xFF8B3DFF)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Modify your form questions or use AI suggestions',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  // Update the form provider with current questions
                  context.read<FormProvider>().updateQuestions(questions);
                  context.read<FormProvider>().updateFormTitle(formTitle);
                  // Navigate to preview page (index 1)
                  widget.onIndexChanged(2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B3DFF), // Purple color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: questions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final question = questions[index];
                if (question.type == 'radio' || question.type == 'checkbox') {
                  return _buildChoiceQuestionCard(index, question);
                } else if (question.type == 'scale') {
                  return _buildScaleQuestionCard(index, question);
                } else {
                  return _buildTextQuestionCard(index, question);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _addNewQuestion,
              icon: const Icon(Icons.add, color: Colors.white70),
              label: const Text(
                'Add New Question',
                style: TextStyle(color: Colors.white70),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextQuestionCard(int index, Question question) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF272726),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: question.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) => _updateQuestionTitle(index, value),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Row(
                children: [
                  PopupMenuButton<String>(
                    initialValue: question.type,
                    onSelected: (value) => _updateQuestionType(index, value),
                    itemBuilder: (context) => questionTypes
                        .map((type) => PopupMenuItem(
                              value: type,
                              child: Text(_getDropdownText(type)),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF414041),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getDropdownText(question.type),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.trashCan, color: Colors.red),
                    iconSize: 16,
                    onPressed: () => _deleteQuestion(index),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextFormField(
            initialValue: question.description ?? '',
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'Description (optional)',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF414041),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                question.description = value;
              });
            },
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _toggleRequired(index),
            child: Row(
              children: [
                const SizedBox(width: 2),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: question.isRequired
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white54,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Required',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceQuestionCard(int index, Question question) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF272726),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: question.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) => _updateQuestionTitle(index, value),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Row(
                children: [
                  PopupMenuButton<String>(
                    initialValue: question.type,
                    onSelected: (value) => _updateQuestionType(index, value),
                    itemBuilder: (context) => questionTypes
                        .map((type) => PopupMenuItem(
                              value: type,
                              child: Text(_getDropdownText(type)),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF414041),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getDropdownText(question.type),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.trashCan, color: Colors.red),
                    iconSize: 16,
                    onPressed: () => _deleteQuestion(index),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...question.options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF414041),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      question.type == 'radio' ? Icons.radio_button_unchecked : Icons.check_box_outline_blank,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: option,
                        style: const TextStyle(color: Colors.white70),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (value) => _updateOption(index, optionIndex, value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => _deleteOption(index, optionIndex),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          TextButton.icon(
            onPressed: () => _addOption(index),
            icon: const Icon(
              Icons.add,
              color: Color(0xFF8B3DFF),
              size: 20,
            ),
            label: const Text(
              'Add Option',
              style: TextStyle(
                color: Color(0xFF8B3DFF),
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _toggleRequired(index),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: question.isRequired
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white54,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Required',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleQuestionCard(int index, Question question) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF272726),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: question.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) => _updateQuestionTitle(index, value),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              Row(
                children: [
                  PopupMenuButton<String>(
                    initialValue: question.type,
                    onSelected: (value) => _updateQuestionType(index, value),
                    itemBuilder: (context) => questionTypes
                        .map((type) => PopupMenuItem(
                              value: type,
                              child: Text(_getDropdownText(type)),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF414041),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getDropdownText(question.type),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.trashCan, color: Colors.red),
                    iconSize: 16,
                    onPressed: () => _deleteQuestion(index),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextFormField(
            initialValue: question.description ?? '',
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'Description (optional)',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF414041),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                question.description = value;
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min Value',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: question.low.toString(),
                      style: const TextStyle(color: Colors.white70),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF414041),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          question.low = int.tryParse(value) ?? 1;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Max Value',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: question.high.toString(),
                      style: const TextStyle(color: Colors.white70),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF414041),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          question.high = int.tryParse(value) ?? 5;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Low Label',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: question.lowLabel,
                      style: const TextStyle(color: Colors.white70),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF414041),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          question.lowLabel = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'High Label',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: question.highLabel,
                      style: const TextStyle(color: Colors.white70),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF414041),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          question.highLabel = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _toggleRequired(index),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: question.isRequired
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white54,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Required',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDropdownText(String type) {
    switch (type) {
      case 'radio':
        return 'Multiple Choice';
      case 'checkbox':
        return 'Checkboxes';
      case 'text':
        return 'Short Answer';
      case 'paragraph':
        return 'Paragraph';
      case 'scale':
        return 'Scale';
      default:
        return type;
    }
  }
}
