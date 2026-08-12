import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/services/word_data_service.dart';
import 'package:easyenglish/services/ranking_service.dart';
import 'package:easyenglish/models/word.dart';
import 'package:easyenglish/models/ranking_data.dart';
import 'package:easyenglish/pages/level_select_page.dart';
import 'package:easyenglish/pages/quiz_result_page.dart';
import 'package:easyenglish/models/quiz_models.dart';
import 'package:easyenglish/services/ad_service.dart';
import 'dart:math';

class WordQuizPage extends StatefulWidget {
  final String userId;
  final List<String> levels;
  final int quizCount;

  const WordQuizPage({
    super.key,
    required this.userId,
    required this.levels,
    required this.quizCount,
  });

  @override
  State<WordQuizPage> createState() => _WordQuizPageState();
}

class _WordQuizPageState extends State<WordQuizPage> {
  final RankingService _rankingService = RankingService();

  List<Word> _allWords = [];
  List<Word> _quizWords = [];
  List<WordQuizAnswer> _quizAnswers = [];

  bool _isLoading = true;
  String? _error;

  int _currentIndex = 0;
  int _correctAnswers = 0;
  String? _selectedMeaning;
  List<String>? _currentOptions;
  bool _isQuizFinished = false;
  bool _isRankingSaved = false;

  // 랭킹 데이터 (누적 합산 기준)
  List<RankingData> _topCorrectRankings = [];
  List<RankingData> _topAccuracyRankings = [];
  RankingData? _userRanking;
  bool _isLoadingRankings = false;

  // 새 디자인 컨셉 색상 (소프트 라벤더 톤) - level_select_page와 통일
  static const Color _primary = Color(0xFF8D85D6);
  static const Color _primaryLight = Color(0xFFF3F1FC);
  static const Color _textDark = Color(0xFF2B2A33);
  static const Color _scaffoldBg = Color(0xFFF7F7FB);

  // 색상 설정
  final Color defaultBorderColor = Colors.grey.shade200;
  final Color barColor = _primary;
  final Color nextButtonColor = _primary;
  final Color prevButtonColor = _primary;

  @override
  void initState() {
    super.initState();
    _fetchWordsAndStartQuiz();
  }

  Future<void> _fetchWordsAndStartQuiz() async {
    try {
      final fetchedData = await WordDataService().fetchWordList();

      final words = <Word>[];
      for (var level in widget.levels) {
        words.addAll(fetchedData[level] ?? []);
      }

      if (!mounted) return;

      if (words.isEmpty) {
        setState(() {
          _error = '선택된 레벨에 단어가 없습니다.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _allWords = words;
        _quizWords = _generateQuiz();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Word> _generateQuiz() {
    final random = Random();
    final List<Word> availableWords = List.from(_allWords);
    final int count = min(widget.quizCount, availableWords.length);

    return List.generate(count, (_) {
      final index = random.nextInt(availableWords.length);
      return availableWords.removeAt(index);
    });
  }

  void _checkAnswer(String selectedMeaning) {
    setState(() => _selectedMeaning = selectedMeaning);
  }

  void _nextQuiz() {
    if (_selectedMeaning == null) return;

    final currentWord = _quizWords[_currentIndex];
    final isCorrect = _selectedMeaning == currentWord.meaning;

    _quizAnswers.add(
      WordQuizAnswer(
        word: currentWord,
        selectedAnswer: _selectedMeaning!,
        isCorrect: isCorrect,
        options: List.from(_currentOptions!),
      ),
    );

    if (isCorrect) _correctAnswers++;

    setState(() {
      _currentIndex++;
      _selectedMeaning = null;
      _currentOptions = null;
    });
  }

  void _previousQuiz() {
    if (_currentIndex == 0) return;

    setState(() {
      _currentIndex--;
      _selectedMeaning = null;
      _currentOptions = null;

      if (_quizAnswers.length > _currentIndex) {
        final removed = _quizAnswers.removeAt(_currentIndex);
        if (removed.isCorrect) _correctAnswers--;
      }
    });
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedMeaning = null;
      _isQuizFinished = false;
      _isRankingSaved = false;
      _currentOptions = null;
      _quizAnswers = [];
      _quizWords = _generateQuiz();
      _topCorrectRankings = [];
      _topAccuracyRankings = [];
      _userRanking = null;
    });
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LevelSelectPage(
                userId: widget.userId,
              )),
      (route) => false,
    );
  }

  Future<void> _goToQuizResult() async {
    final userId = await _rankingService.getUserName() ?? "익명";

    if (!mounted) return;

    // 구독 중이 아니면 결과 화면 진입 전에 전면 광고를 먼저 보여줍니다.
    AdService().showBeforeResult(() {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizResultPage(
            userId: userId,
            quizAnswers: _quizAnswers,
            correctAnswers: _correctAnswers,
            totalQuestions: _quizWords.length,
            levels: widget.levels,
          ),
        ),
      );
    });
  }

  Future<void> _calculateFinalScore() async {
    debugPrint('[랭킹진단] _calculateFinalScore 호출됨. isRankingSaved=$_isRankingSaved');
    _isQuizFinished = true;
    if (!_isRankingSaved) {
      await _saveRanking();
      _isRankingSaved = true;
      await _loadRankings();
    }
  }

  Future<void> _saveRanking() async {
    try {
      final userName = await _rankingService.getUserName() ?? "익명";
      final uid = await _rankingService.getUserId() ?? "";

      final ranking = RankingData(
        userName: userName,
        correctAnswers: _correctAnswers,
        totalQuestions: _quizWords.length,
        accuracy: _correctAnswers / _quizWords.length,
        testDate: DateTime.now(),
        level: widget.levels.join(', '),
        userId: uid,
      );

      // 개별 시험 기록은 그대로 저장 (히스토리 보존).
      // 화면에 보여줄 "내 기록"은 아래 _loadRankings()에서 누적 합산으로 다시 채워집니다.
      await _rankingService.addRanking(ranking);
    } catch (e) {
      debugPrint('랭킹 저장 실패: $e');
    }
  }

  Future<void> _loadRankings() async {
    setState(() => _isLoadingRankings = true);

    try {
      // ranking_page.dart와 동일하게 사용자별 누적 합산 데이터를 사용합니다.
      final aggregatedRankings = await _rankingService.getAggregatedRankings();
      final uid = await _rankingService.getUserId() ?? "";

      debugPrint('[랭킹진단] 내 uid: $uid');
      debugPrint('[랭킹진단] 전체 집계 사용자 수: ${aggregatedRankings.length}');

      // 누적 정답 수 기준 상위 5위
      final correctRankings = List<RankingData>.from(aggregatedRankings);
      correctRankings
          .sort((a, b) => b.correctAnswers.compareTo(a.correctAnswers));
      _topCorrectRankings = correctRankings.take(5).toList();

      // 누적 정확도 기준 상위 5위
      final accuracyRankings = List<RankingData>.from(aggregatedRankings);
      accuracyRankings.sort((a, b) => b.accuracy.compareTo(a.accuracy));
      _topAccuracyRankings = accuracyRankings.take(5).toList();

      // 내 누적 랭킹 찾기 - 닉네임이 아니라 uid로 정확히 매칭
      final mine = aggregatedRankings.where((r) => r.userId == uid).toList();
      debugPrint('[랭킹진단] 내 uid와 일치하는 집계 항목 수: ${mine.length}');
      if (mine.isNotEmpty) {
        debugPrint('[랭킹진단] 내 누적: ${mine.first.correctAnswers}/${mine.first.totalQuestions}');
      }
      _userRanking = mine.isNotEmpty ? mine.first : null;
    } catch (e, st) {
      debugPrint('[랭킹진단] 랭킹 로드 실패: $e');
      debugPrint('$st');
    } finally {
      setState(() => _isLoadingRankings = false);
    }
  }

  List<String> _getMeaningOptions(Word word) {
    if (_currentOptions != null) return _currentOptions!;

    final random = Random();
    final options = <String>[word.meaning];

    final allMeanings = _allWords
        .where((w) => w.word != word.word)
        .map((w) => w.meaning)
        .toSet()
        .toList()
      ..shuffle(random);

    while (options.length < 4 && allMeanings.isNotEmpty) {
      options.add(allMeanings.removeAt(0));
    }

    if (options.length < 4) {
      final tempWords = _allWords.where((w) => w.word != word.word).toList();
      while (options.length < 4 && tempWords.isNotEmpty) {
        options.add(tempWords[random.nextInt(tempWords.length)].meaning);
      }
    }

    options.shuffle(random);
    _currentOptions = List.from(options);
    return _currentOptions!;
  }

  // level_select_page와 동일한 라벤더 그라데이션 앱바.
  // 페이지 내부에서만 쓰는 헬퍼로, 아래 4개 화면(오류/단어없음/결과/퀴즈)에서 재사용합니다.
  PreferredSizeWidget _buildGradientAppBar(
    String title, {
    String? emoji,
    Widget? leading,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: leading == null ? 20 : 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEFEAFF),
              Color(0xFFD8D1FF),
              Color(0xFFC8C1FD),
            ],
          ),
        ),
      ),
      leading: leading,
      title: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji, style: const TextStyle(fontSize: 16)),
            SizedBox(width: 8.w),
          ],
          Text(
            title,
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon) {
    return Container(
      width: 30.w,
      height: 30.w,
      decoration: const BoxDecoration(
        color: _primaryLight,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _primary, size: 16.sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: _scaffoldBg,
        appBar: _buildGradientAppBar('오류'),
        body: Center(child: Text(_error!)),
      );
    }
    if (_quizWords.isEmpty) {
      return Scaffold(
        backgroundColor: _scaffoldBg,
        appBar: _buildGradientAppBar('단어 없음'),
        body: const Center(child: Text('퀴즈를 위한 단어가 없습니다.')),
      );
    }

    if (_currentIndex >= _quizWords.length) {
      if (!_isQuizFinished) _calculateFinalScore();
      return _buildResultScreen(context);
    }

    return _buildQuizScreen(context);
  }

  Widget _buildRankingCard(
      String title, List<RankingData> rankings, String valueType) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: Color(0xFFF0EFF6)),
      ),
      margin: EdgeInsets.symmetric(vertical: 6.h),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            SizedBox(height: 8.h),
            if (rankings.isEmpty)
              const Text('랭킹 데이터가 없습니다.', style: TextStyle(color: Colors.grey))
            else
              Column(
                children: rankings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ranking = entry.value;
                  final isUser = _userRanking != null &&
                      ranking.userId == _userRanking!.userId;

                  String value;
                  if (valueType == 'correct') {
                    value =
                        '${ranking.correctAnswers}/${ranking.totalQuestions}개';
                  } else {
                    value = '${(ranking.accuracy * 100).toStringAsFixed(1)}%';
                  }

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 2.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 4.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isUser ? _primaryLight : null,
                      borderRadius: BorderRadius.circular(8.r),
                      border: isUser
                          ? Border.all(color: _primary.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16.w,
                          height: 16.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == 0
                                ? Colors.amber
                                : index == 1
                                    ? Colors.grey
                                    : index == 2
                                        ? Colors.brown
                                        : Colors.grey.shade300,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            ranking.userName,
                            style: TextStyle(
                              fontWeight:
                                  isUser ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUser ? _primary : null,
                          ),
                        ),
                        if (isUser)
                          Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: Icon(Icons.person,
                                size: 16.sp, color: _primary),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: _buildGradientAppBar(
        '퀴즈 결과',
        emoji: '🎉',
        leading: IconButton(
          icon: _buildAppBarIcon(Icons.home),
          tooltip: '홈으로',
          onPressed: _goToHome,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 30.w), //전체 가로 size 조정
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFFF0EFF6)),
              ),
              child: Column(
                children: [
                  Text(
                    '총 ${_quizWords.length}문제 중 $_correctAnswers개 맞춤! 🎉',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18.sp)
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '정확도: ${((_correctAnswers / _quizWords.length) * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 115.w,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text('시험 결과'),
                          onPressed: _goToQuizResult,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: BorderSide(color: _primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      SizedBox(
                        width: 115.w,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시작'),
                          onPressed: _resetQuiz,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 4.h),

            if (_isLoadingRankings)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: const BorderSide(color: Color(0xFFF0EFF6)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(40.w),
                  child: const Center(child: CircularProgressIndicator(color: _primary)),
                ),
              )
            else ...[
              _buildRankingCard(
                '🏆 누적 정답수 TOP 5',
                _topCorrectRankings,
                'correct',
              ),
              _buildRankingCard(
                '🎯 누적 정확도 TOP 5',
                _topAccuracyRankings,
                'accuracy',
              ),

              if (_userRanking != null)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: _primary.withValues(alpha: 0.2)),
                  ),
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  color: _primaryLight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📊 내 누적 기록',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: _primary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.person, color: _primary),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                _userRanking!.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '누적 정답: ${_userRanking!.correctAnswers}/${_userRanking!.totalQuestions}개'),
                            Text(
                                '누적 정확도: ${(_userRanking!.accuracy * 100).toStringAsFixed(1)}%'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizScreen(BuildContext context) {
    final currentWord = _quizWords[_currentIndex];
    final options = _getMeaningOptions(currentWord);
    final optionNumbers = ["①", "②", "③", "④"];

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: _buildGradientAppBar(
        '${widget.levels.join(', ')} 단어시험',
        emoji: '📝',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400.w),
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('문제 ${_currentIndex + 1}/${_quizWords.length}'),
                        Text(
                          '진도: ${(((_currentIndex + 1) / _quizWords.length) * 100).toInt()}%',
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _quizWords.length,
                        minHeight: 10.h,
                        backgroundColor: Colors.grey.shade200,
                        color: barColor,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    Container(
                      padding: EdgeInsets.symmetric(vertical: 30.h),
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Column(
                        children: [
                          Text(currentWord.word,
                              style: TextStyle(
                                  fontSize: 32.sp, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6.h),
                          Text('[${currentWord.pronunciation}]',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    SizedBox(height: 10.h),

                    Column(
                      children: options.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final option = entry.value;
                        final isSelected = _selectedMeaning == option;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.symmetric(vertical: 4.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                                color: isSelected
                                    ? _primary
                                    : defaultBorderColor,
                                width: 1.5),
                            color: isSelected
                                ? _primaryLight
                                : Colors.grey.shade50,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10.r),
                              onTap: () => _checkAnswer(option),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 12.h, horizontal: 16.w),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                          '${optionNumbers[idx]} $option',
                                          style: TextStyle(
                                              color: isSelected
                                                  ? _primary
                                                  : Colors.black87,
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle,
                                          color: _primary, size: 20.sp),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 140.w,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: _currentIndex > 0 ? _previousQuiz : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: prevButtonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back_ios, size: 18.sp),
                                SizedBox(width: 4.w),
                                const Text('이전'),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140.w,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed:
                                _selectedMeaning != null ? _nextQuiz : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: nextButtonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('다음'),
                                SizedBox(width: 4.w),
                                Icon(Icons.arrow_forward_ios, size: 18.sp),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}