import 'package:flutter/foundation.dart';
import '../models/question.dart';
import 'package:flutter/material.dart';

class ChatMessage {
  final bool isUser;
  final String message;
  final bool animate;
  final Widget? formPreview;
  final bool isNew;
  bool hasBeenShown;

  ChatMessage({
    required this.isUser,
    required this.message,
    this.animate = false,
    this.formPreview,
    this.isNew = true,
    this.hasBeenShown = false,
  });

  ChatMessage markAsOld() {
    return ChatMessage(
      isUser: isUser,
      message: message,
      animate: animate,
      formPreview: formPreview,
      isNew: false,
      hasBeenShown: true,
    );
  }

  ChatMessage markAsShown() {
    return ChatMessage(
      isUser: isUser,
      message: message,
      animate: animate,
      formPreview: formPreview,
      isNew: isNew,
      hasBeenShown: true,
    );
  }
}

class FormProvider with ChangeNotifier {
  List<ChatMessage> _chatHistory = [];
  String _formTitle = '';
  String _formDescription = '';
  List<dynamic> _questions = [];
  String _formId = '';
  String _formDocumentId = '';
  bool _isExportedGoogle = false;
  bool _isEmailSent = false;
  bool _isFormExported = false;
  String? _currentFormId;

  List<ChatMessage> get chatHistory => _chatHistory;
  String get formTitle => _formTitle;
  String get formDescription => _formDescription;
  List<dynamic> get questions => _questions;
  String get formId => _formId;
  String get formDocumentId => _formDocumentId;
  bool get isExportedGoogle => _isExportedGoogle;
  bool get isEmailSent => _isEmailSent;
  bool get isFormExported => _isFormExported;
  String get currentFormId => _currentFormId ?? '';

  set formId(String id) {
    _formId = id;
    notifyListeners();
  }

  set formDocumentId(String id) {
    _formDocumentId = id;
    notifyListeners();
  }

  set isExportedGoogle(bool value) {
    _isExportedGoogle = value;
    notifyListeners();
  }

  set isEmailSent(bool value) {
    _isEmailSent = value;
    notifyListeners();
  }

  void setFormExported(bool value) {
    _isFormExported = value;
    notifyListeners();
  }

  void addChatMessage(ChatMessage message) {
    if (message.message == "...") {
      final loadingIndex = _chatHistory.indexWhere((msg) => msg.message == "...");
      if (loadingIndex != -1) {
        _chatHistory[loadingIndex] = message;
      } else {
        _chatHistory.add(message);
      }
    } else {
      _chatHistory.add(message);
    }
    notifyListeners();
  }

  void removeChatMessage(int index) {
    if (index >= 0 && index < _chatHistory.length) {
      _chatHistory.removeAt(index);
      notifyListeners();
    }
  }

  void updateForm({
    required String title,
    required String description,
    required List<dynamic> questions,
  }) {
    _formTitle = title;
    _formDescription = description;
    _questions = questions;
    notifyListeners();
  }

  void clearForm() {
    _formTitle = '';
    _formDescription = '';
    _questions = [];
    notifyListeners();
  }

  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  void updateQuestions(List<Question> newQuestions) {
    _questions = List.from(newQuestions);
    notifyListeners();
  }

  void updateFormTitle(String newTitle) {
    _formTitle = newTitle;
    notifyListeners();
  }

  void updateMessageAsShown(int index) {
    if (index >= 0 && index < _chatHistory.length) {
      _chatHistory[index] = _chatHistory[index].markAsShown();
      notifyListeners();
    }
  }

  void replaceChatMessage(int index, ChatMessage newMessage) {
    if (index >= 0 && index < _chatHistory.length) {
      _chatHistory[index] = newMessage;
      notifyListeners();
    }
  }

  void markMessageAsShown(ChatMessage message) {
    final index = _chatHistory.indexOf(message);
    if (index != -1) {
      _chatHistory[index].hasBeenShown = true;
      notifyListeners();
    }
  }

  Map<String, dynamic> getFormData() {
    return {
      'title': _formTitle,
      'documentTitle': _formTitle,
      'items': _questions.asMap().entries.map((entry) {
        final int index = entry.key;
        final question = entry.value;

        return {
          'createItem': {
            'item': {
              'title': question.title,
              'questionItem': {
                'question': {
                  'required': question.isRequired,
                  ...(_getQuestionTypeData(question)),
                }
              }
            },
            'location': {'index': index}
          }
        };
      }).toList(),
    };
  }

  Map<String, dynamic> _getQuestionTypeData(Question question) {
    switch (question.type.toLowerCase()) {
      case 'radio':
        return {
          'choiceQuestion': {
            'type': question.type.toUpperCase(),
            'options': question.options.map((option) => {'value': option}).toList(),
          }
        };
      case 'checkbox':
        return {
          'choiceQuestion': {
            'type': question.type.toUpperCase(),
            'options': question.options.map((option) => {'value': option}).toList(),
          }
        };
      case 'dropdown':
        return {
          'choiceQuestion': {
            'type': question.type.toUpperCase(),
            'options': question.options.map((option) => {'value': option}).toList(),
          }
        };
      case 'scale':
        return {
          'scaleQuestion': {'low': question.low, 'high': question.high, 'lowLabel': question.lowLabel, 'highLabel': question.highLabel}
        };
      case 'paragraph':
        return {
          'textQuestion': {'paragraph': true}
        };
      case 'text':
      default:
        return {
          'textQuestion': {'paragraph': false}
        };
    }
  }

  void setCurrentFormId(String formId) {
    _currentFormId = formId;
    notifyListeners();
  }
}
