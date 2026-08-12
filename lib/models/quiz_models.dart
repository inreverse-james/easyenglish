import 'package:easyenglish/models/word.dart';

class WordQuizAnswer {
  final Word word;
  final String selectedAnswer;
  final bool isCorrect;
  final List<String> options;

  WordQuizAnswer({
    required this.word,
    required this.selectedAnswer,
    required this.isCorrect,
    required this.options,
  });
}
