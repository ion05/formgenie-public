import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/models/question.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/form_provider.dart';
import '../globals/globals.dart';

class HistoryPage extends StatefulWidget {
  final Function(String) onFormIdChanged;
  final Function(int) onIndexChanged;
  const HistoryPage({super.key, required this.onFormIdChanged, required this.onIndexChanged});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Stream<QuerySnapshot> _formsStream;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _formsStream = FirebaseFirestore.instance.collection('forms').where('user', isEqualTo: userId).snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildShimmerFormCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _loadFormData(String documentId, Map<String, dynamic> formData, int index) async {
    setState(() {
      Globals.setCurrentFormFirestoreId(documentId);
    });
    // widget.onFormIdChanged(documentId);

    final formProvider = Provider.of<FormProvider>(context, listen: false);

    formProvider.clearChatHistory();

    // Convert the questions data to List<Question>
    final questions = (formData['questions'] as List?)?.map((q) {
          final Map<String, dynamic> questionData = Map<String, dynamic>.from(q);
          return Question(
            title: questionData['title'] ?? '',
            type: questionData['type'] ?? 'text',
            description: questionData['description'],
            isRequired: questionData['isRequired'] ?? false,
            options: List<String>.from(questionData['options'] ?? []),
            low: questionData['low'] ?? 1,
            high: questionData['high'] ?? 5,
            lowLabel: questionData['lowLabel'] ?? 'Not at all',
            highLabel: questionData['highLabel'] ?? 'Completely',
          );
        }).toList() ??
        [];

    formProvider.updateForm(
      title: formData['title'] ?? 'Untitled Form',
      description: formData['description'] ?? '',
      questions: questions,
    );

    formProvider.isExportedGoogle = formData['exportedGoogle'] ?? false;
    formProvider.isEmailSent = formData['emailSent'] ?? false;
    formProvider.formId = formData['formId'] ?? '';
    formProvider.setFormExported(formData['exportedGoogle'] ?? false);

    setState(() {
      widget.onIndexChanged(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171616),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(45, 40, 45, 24),
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
                      'Your Forms',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage and edit your created forms',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 300,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          icon: Icon(Icons.search, color: Colors.grey[400]),
                          hintText: 'Search forms...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onFormIdChanged('');
                        widget.onIndexChanged(0);
                        context.read<FormProvider>().clearForm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'New Form',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _formsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView.separated(
                      itemCount: 3,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => _buildShimmerFormCard(),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint('Error loading forms: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Error loading forms',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    );
                  }

                  final forms = snapshot.data?.docs ?? [];
                  final filteredForms = forms.where((form) {
                    final data = form.data() as Map<String, dynamic>;
                    return data['title'].toString().toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filteredForms.isEmpty) {
                    return Center(
                      child: Text(
                        'No forms found',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredForms.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = filteredForms[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildFormCard(
                        title: data['title'] ?? 'Untitled Form',
                        createdTime: _formatTimestamp(data['createdAt'] as int),
                        questions: (data['questions'] as List?)?.length ?? 0,
                        isActive: data['exportedGoogle'] ?? false,
                        documentId: doc.id,
                        formData: data,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final difference = now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp));

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
  }

  Widget _buildFormCard({
    required String title,
    required String createdTime,
    required int questions,
    required String documentId,
    required Map<String, dynamic> formData,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Created $createdTime',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1A472A) : const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Draft',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF4ADE80) : Colors.orange[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$questions questions',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(FontAwesomeIcons.link, color: Colors.green, size: 12),
                        label: const Text('Copy Share URL', style: TextStyle(color: Colors.green, fontSize: 12)),
                        onPressed: () {
                          // TODO: Implement URL copying functionality
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _loadFormData(documentId, formData, 2),
                child: Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: const Color(0xFF8B5CF6),
                        fontSize: 14,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: const Color(0xFF8B5CF6),
                      size: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(FontAwesomeIcons.penToSquare, color: Colors.yellow, size: 16),
                    label: const Text('Edit Form', style: TextStyle(color: Colors.yellow)),
                    onPressed: () => _loadFormData(documentId, formData, 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      minimumSize: const Size(140, 0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(FontAwesomeIcons.trashCan, color: Colors.red, size: 16),
                    label: const Text('Delete Form', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      // delete form from firebase and reload and meanwhile show shimmer
                      FirebaseFirestore.instance.collection('forms').doc(documentId).delete();
                      setState(() {
                        _formsStream = FirebaseFirestore.instance.collection('forms').where('user', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
                      minimumSize: const Size(140, 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
