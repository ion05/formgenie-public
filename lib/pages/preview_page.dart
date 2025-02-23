import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';
import '../models/question.dart';

class PreviewPage extends StatefulWidget {
  final Function(int) onIndexChanged;

  const PreviewPage({super.key, required this.onIndexChanged});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF171616),
      padding: const EdgeInsets.fromLTRB(45, 50, 45, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.read<FormProvider>().formTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              //back to edit button
              ElevatedButton.icon(
                onPressed: () {
                  widget.onIndexChanged(1);
                },
                icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.white),
                label: const Text(
                  'Edit Form',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B3DFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  widget.onIndexChanged(3);
                },
                icon: const Icon(FontAwesomeIcons.share, color: Colors.white),
                label: const Text(
                  'Export Form',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
          const SizedBox(height: 30),
          Expanded(
            child: Consumer<FormProvider>(
              builder: (context, formProvider, child) {
                return ListView.separated(
                  itemCount: formProvider.questions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final question = formProvider.questions[index];
                    return _buildQuestionPreview(question);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPreview(Question question) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF272726),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                question.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (question.isRequired)
                Text(
                  " *",
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                  ),
                ),
            ],
          ),
          if (question.description != null && question.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              question.description!,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (question.type == 'text' || question.type == 'paragraph')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                enabled: false,
                decoration: InputDecoration(
                  // hintText: 'Your answer',
                  // hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF414041),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: question.type == 'paragraph' ? 3 : 1,
              ),
            )
          else if (question.type == 'radio' || question.type == 'checkbox')
            Column(
              children: question.options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        question.type == 'radio' ? Icons.radio_button_unchecked : Icons.check_box_outline_blank,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option,
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else if (question.type == 'scale')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(question.lowLabel, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(width: 12),
                  for (int i = question.low; i <= question.high; i++)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.radio_button_unchecked,
                        size: 20,
                        color: Colors.white54,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Text(question.highLabel, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
