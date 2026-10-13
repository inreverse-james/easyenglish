// lib/pages/word_study_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:easyenglish/theme/app_theme.dart';
import 'package:easyenglish/models/word.dart';
import 'package:easyenglish/services/word_data_service.dart';
import 'package:easyenglish/pages/settings_page.dart';
import 'package:easyenglish/widgets/coupang_banner.dart';

class WordStudyPage extends StatefulWidget {
  final String level;

  const WordStudyPage({super.key, required this.level});

  @override
  State<WordStudyPage> createState() => _WordStudyPageState();
}

class _WordStudyPageState extends State<WordStudyPage> {
  // Services
  final FlutterTts _tts = FlutterTts();
  final WordDataService _dataService = WordDataService();

  // Data
  List<Word> _wordList = [];
  bool _isLoading = true;
  String? _error;

  // Study state
  int _currentIndex = 0;
  bool _showMeaning = false;
  bool _alwaysShowMeaning = false;

  // 책갈피: 레벨마다 마지막 1개만 저장
  int? _savedBookmarkIndex;

  // TTS
  bool _isSpeaking = false;

  // 빠른 이동
  int _quickMoveStep = 10;
  final List<int> _quickMoveOptions = const [10, 50, 100];

  // 자동 재생
  bool _isAutoPlay = false;
  int _autoPlayInterval = 5;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _fetchWords();
    _initTts();
  }

  @override
  void dispose() {
    // 화면을 나갈 때 자동 재생 타이머와 "화면 켜짐 유지"를 반드시 해제합니다.
    // (해제하지 않으면 다른 화면에서도 타이머가 계속 돌고 화면이 꺼지지 않습니다.)
    _autoPlayTimer?.cancel();
    WakelockPlus.disable();
    _tts.stop();
    super.dispose();
  }

  // ------------------------------ Data ------------------------------
  Future<void> _fetchWords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _dataService.getWordsForLevel(widget.level);
      if (!mounted) return;

      if (list.isEmpty) {
        setState(() {
          _wordList = [];
          _isLoading = false;
          _error = '단어 데이터가 존재하지 않습니다.';
        });
        return;
      }

      setState(() {
        _wordList = list;
        _isLoading = false;
      });

      await _loadBookmark();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '단어를 불러오지 못했어요.\n인터넷 연결을 확인하고 다시 시도해 주세요.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('${widget.level}_bookmark');
    if (!mounted) return;
    if (idx != null && idx >= 0 && idx < _wordList.length) {
      setState(() {
        _savedBookmarkIndex = idx;
        _currentIndex = idx; // 마지막으로 저장한 단어로 이동
      });
    }
  }

  Future<void> _saveBookmark() async {
    if (_wordList.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.level}_bookmark';

    if (_savedBookmarkIndex == _currentIndex) {
      await prefs.remove(key);
      if (!mounted) return;
      setState(() => _savedBookmarkIndex = null);
      _showSnack('책갈피를 해제했어요.');
    } else {
      await prefs.setInt(key, _currentIndex);
      if (!mounted) return;
      setState(() => _savedBookmarkIndex = _currentIndex);
      _showSnack('현재 단어를 책갈피에 저장했어요.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------ TTS ------------------------------
  Future<void> _initTts() async {
    try {
      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _tts.setErrorHandler((msg) {
        if (mounted) setState(() => _isSpeaking = false);
        debugPrint('TTS error: $msg');
      });

      for (final l in ['en-US', 'en-GB', 'en-AU', 'en']) {
        try {
          await _tts.setLanguage(l);
          break;
        } catch (_) {}
      }

      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.3);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  String _preprocessText(String s) {
    return s
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
    try {
      await _tts.speak(_preprocessText(text));
    } catch (e) {
      debugPrint('Speak failed: $e');
      if (!mounted) return;
      _showSnack('음성 재생 중 오류가 발생했어요.');
    }
  }

  // ------------------------------ Controls ------------------------------
  void _nextWord() {
    if (_wordList.isEmpty || !mounted) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _wordList.length;
      _showMeaning = false; //
    });
  }

  void _previousWord() {
    if (_wordList.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _wordList.length) % _wordList.length;
      _showMeaning = false; //
    });
  }

  void _quickMoveForward() {
    if (_wordList.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + _quickMoveStep) % _wordList.length;
      _showMeaning = false; //
    });
  }

  void _quickMoveBackward() {
    if (_wordList.isEmpty) return;
    setState(() {
      _currentIndex =
          (_currentIndex - _quickMoveStep + _wordList.length) % _wordList.length;
          _showMeaning = false; //
    });
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
      if (_isAutoPlay) {
        WakelockPlus.enable();
        _startTimer();
      } else {
        WakelockPlus.disable();
        _autoPlayTimer?.cancel();
      }
    });
  }

  void _startTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(Duration(seconds: _autoPlayInterval), (_) {
      if (_isAutoPlay) _nextWord();
    });
  }

  void _toggleMeaning() {
    if (_alwaysShowMeaning) return;
    setState(() => _showMeaning = !_showMeaning);
  }

  void _toggleAlwaysShowMeaning() {
    setState(() {
      _alwaysShowMeaning = !_alwaysShowMeaning;
      if (_alwaysShowMeaning) _showMeaning = true;
    });
  }

  // ------------------------- UI Helper -------------------------
  // 예문 안에서 주어/동사를 색으로 강조
  Widget _buildHighlightedText({
    required String fullText,
    required TextStyle defaultStyle,
    required Set<String> subjectWords,
    required Set<String> verbWords,
  }) {
    final targets = {...subjectWords, ...verbWords}
        .where((w) => w.isNotEmpty)
        .map((w) => r'\b' + RegExp.escape(w) + r'\b')
        .join('|');

    if (fullText.isEmpty || targets.isEmpty) {
      return Text(fullText, style: defaultStyle, textAlign: TextAlign.center);
    }

    final pattern = RegExp('($targets)', caseSensitive: false);
    final List<InlineSpan> spans = [];

    fullText.splitMapJoin(
      pattern,
      onMatch: (m) {
        final original = m.group(0)!;
        final lower = original.toLowerCase();

        TextStyle style = defaultStyle.copyWith(fontWeight: FontWeight.bold);
        if (subjectWords.contains(lower)) {
          style = style.copyWith(backgroundColor: AppColors.subjectHighlight);
        }
        if (verbWords.contains(lower)) {
          style = style.copyWith(backgroundColor: AppColors.verbHighlight);
        }
        spans.add(TextSpan(text: original, style: style));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(text: n, style: defaultStyle));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }

  Widget _speakerButton(VoidCallback onTap, {double size = 18}) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.volume_up_rounded,
            color: AppColors.primary, size: size.sp),
      ),
    );
  }

  // ------------------------------ UI ------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildScaffold(const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _buildScaffold(
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 20.h),
                FilledButton(
                  onPressed: _fetchWords,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final w = _wordList[_currentIndex];
    final showMeaning = _showMeaning || _alwaysShowMeaning;
    final isBookmarked = _savedBookmarkIndex == _currentIndex;

    final subjectWords = <String>{
      if (w.subject != null) w.subject!.toLowerCase(),
    };
    final verbWords = <String>{
      if (w.verb != null) w.verb!.toLowerCase(),
    };

    return _buildScaffold(
      SafeArea(
        child: Column(
          children: [
            // 위쪽: 스크롤 영역 (카드)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
                child: Column(
                  children: [
                    _buildTopRow(),
                    SizedBox(height: 1.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _wordList.length,
                        minHeight: 4.h,
                        backgroundColor: AppColors.separator,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildWordCard(w, showMeaning, isBookmarked, subjectWords,
                        verbWords),
                    SizedBox(height: 8.h),
                    _buildQuickMove(),
                    TextButton.icon(
                      onPressed: _alwaysShowMeaning ? null : _toggleMeaning,
                      icon: Icon(
                        showMeaning
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18.sp,
                      ),
                      label: Text(
                        showMeaning ? '뜻 숨기기' : '뜻 보기',
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 아래쪽: 항상 보이는 컨트롤
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
              child: Column(
                children: [
                  _buildPrevNext(),
                  SizedBox(height: 12.h),
                  _buildAutoPlayRow(),
                  SizedBox(height: 60.h),
                  SizedBox(height: 50, child: const CoupangBanner()),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_currentIndex + 1} / ${_wordList.length}',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '뜻 항상 보기',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(width: 4.w),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _alwaysShowMeaning,
                onChanged: (_) => _toggleAlwaysShowMeaning(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordCard(Word w, bool showMeaning, bool isBookmarked,
      Set<String> subjectWords, Set<String> verbWords) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 320.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 책갈피 버튼 (오른쪽 위)
          Positioned(
            top: 8.h,
            right: 8.w,
            child: IconButton(
              tooltip: '책갈피',
              onPressed: _saveBookmark,
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isBookmarked
                    ? AppColors.warning
                    : const Color(0xFFC7C7CC),
                size: 28.sp,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          w.word,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      _speakerButton(() => _speak(w.word)),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '[ ${w.pronunciation.replaceAll(RegExp(r'\s'), '')} ]',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: showMeaning
                        ? _buildMeaningSection(
                            w, subjectWords, verbWords)
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeaningSection(
      Word w, Set<String> subjectWords, Set<String> verbWords) {
    return Column(
      children: [
        SizedBox(height: 18.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                w.partOfSpeech,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Flexible(
              child: Text(
                w.meaning,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (w.example.isNotEmpty) ...[
          SizedBox(height: 12.h),
          const Divider(),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildHighlightedText(
                  fullText: w.example,
                  subjectWords: subjectWords,
                  verbWords: verbWords,
                  defaultStyle: TextStyle(
                    fontSize: 17.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _speakerButton(() => _speak(w.example), size: 18),
            ],
          ),
          if (w.exampleMeaning.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                w.exampleMeaning,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildQuickMove() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전으로 $_quickMoveStep개 이동',
          icon: Icon(Icons.keyboard_double_arrow_left_rounded,
              size: 26.sp, color: AppColors.textSecondary),
          onPressed: _quickMoveBackward,
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _quickMoveStep,
            borderRadius: BorderRadius.circular(12.r),
            dropdownColor: AppColors.surface,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            items: _quickMoveOptions
                .map((v) => DropdownMenuItem<int>(
                      value: v,
                      child: Text('$v개씩'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _quickMoveStep = v);
            },
          ),
        ),
        IconButton(
          tooltip: '다음으로 $_quickMoveStep개 이동',
          icon: Icon(Icons.keyboard_double_arrow_right_rounded,
              size: 26.sp, color: AppColors.textSecondary),
          onPressed: _quickMoveForward,
        ),
      ],
    );
  }

  Widget _buildPrevNext() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54.h,
            child: FilledButton(
              onPressed: _previousWord,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text('이전 단어',
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: SizedBox(
            height: 54.h,
            child: FilledButton(
              onPressed: _nextWord,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text('다음 단어',
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoPlayRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Text(
            _isAutoPlay ? '자동모드' : '수동모드',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 8.w),
          Switch(
            value: _isAutoPlay,
            onChanged: (_) => _toggleAutoPlay(),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _autoPlayInterval,
              borderRadius: BorderRadius.circular(12.r),
              dropdownColor: AppColors.surface,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              items: [5, 10, 20]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v초')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _autoPlayInterval = v);
                if (_isAutoPlay) _startTimer();
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }

  Scaffold _buildScaffold(Widget body) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.level} 단어 공부'),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: body,
    );
  }
}
