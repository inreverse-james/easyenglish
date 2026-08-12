class Word {
  final String word;
  final String pronunciation;
  final String partOfSpeech;
  final String meaning;
  final String example;
  final String exampleMeaning;
  final String? subject;
  final String? verb;

  Word({
    required this.word,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.meaning,
    required this.example,
    required this.exampleMeaning,
    this.subject,
    this.verb,
  });

  factory Word.fromList(List<dynamic> data) {
    return Word(
      word: data[1].toString().trim(),
      pronunciation: data[2].toString().trim(),
      partOfSpeech: data[3].toString().trim(),
      meaning: data[4].toString().trim(),
      example: data[5].toString().trim(),
      exampleMeaning: data[6].toString().trim(),
      subject:
          data.length > 7 && data[7] != null ? data[7].toString().trim() : null,
      verb:
          data.length > 8 && data[8] != null ? data[8].toString().trim() : null,
    );
  }
}
