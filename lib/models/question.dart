class Question {
  String title;
  String type;
  String? description;
  bool isRequired;
  List<String> options;
  int low;
  int high;
  String lowLabel;
  String highLabel;
  int? minValue;
  int? maxValue;

  Question({
    required this.title,
    required this.type,
    this.description,
    this.isRequired = false,
    List<String>? options,
    this.low = 1,
    this.high = 5,
    this.lowLabel = 'Not at all',
    this.highLabel = 'Completely',
    this.minValue,
    this.maxValue,
  }) : options = options?.toList() ?? [];

  Question copyWith({
    String? title,
    String? type,
    String? description,
    bool? isRequired,
    List<String>? options,
    int? low,
    int? high,
    String? lowLabel,
    String? highLabel,
  }) {
    return Question(
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
      options: options ?? List.from(this.options),
      low: low ?? this.low,
      high: high ?? this.high,
      lowLabel: lowLabel ?? this.lowLabel,
      highLabel: highLabel ?? this.highLabel,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'description': description,
      'isRequired': isRequired,
      'options': options,
      'low': low,
      'high': high,
      'lowLabel': lowLabel,
      'highLabel': highLabel,
    };
  }
}
