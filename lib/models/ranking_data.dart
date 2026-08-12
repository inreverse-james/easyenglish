// lib/models/ranking_data.dart

class RankingData {
  final String userId;
  final String userName;
  final int correctAnswers;
  final int totalQuestions;
  final double accuracy;
  final DateTime testDate;
  final String level; // 추가: 레벨 정보

  RankingData({
    required this.userId,
    required this.userName,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.accuracy,
    required this.testDate,
    required this.level, // 추가: 레벨 정보
  });

  factory RankingData.fromJson(Map<String, dynamic> json) {
    return RankingData(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      correctAnswers: json['correctAnswers'] as int,
      totalQuestions: json['totalQuestions'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      testDate: DateTime.parse(json['testDate'] as String),
      level: json['level'] as String, // 추가
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'accuracy': accuracy,
      'testDate': testDate.toIso8601String(),
      'level': level, // 추가
    };
  }
}
