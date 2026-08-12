// lib/pages/word_study_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/word.dart';
import '../services/word_data_service.dart';
import 'package:easyenglish/pages/settings_page.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:easyenglish/widgets/coupang_banner.dart';

class WordStudyPage extends StatefulWidget {
  final String level;

  const WordStudyPage({
    super.key,
    required this.level,
  });

  @override
  State<WordStudyPage> createState() => _WordStudyPageState();
}

class _WordStudyPageState extends State<WordStudyPage> {
  // 새 디자인 컨셉 색상 (소프트 라벤더 톤)
  static const Color _primary = Color(0xFF8D85D6);
  static const Color _primaryLight = Color(0xFFF3F1FC);
  static const Color _textDark = Color(0xFF2B2A33);

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

  // Bookmark: we only keep the last saved index for this level
  int? _savedBookmarkIndex; // cached in memory for quick compare

  // TTS state
  bool _isSpeaking = false;

  // Quick-move
  int _quickMoveStep = 10;
  final List<int> _quickMoveOptions = const [10, 50, 100];

  @override
  void initState() {
    super.initState();
    _fetchWords();
    _initTts();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  bool _isAutoPlay = false;
  int _autoPlayInterval = 5;
  Timer? _autoPlayTimer;

  // ------------------------------ Data ------------------------------
  Future<void> _fetchWords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!mounted) return;

      // WordDataService를 통해 데이터 가져오기
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

      // Load bookmark only after list is ready
      await _loadBookmark();

      // Bookmark가 범위를 벗어나는 경우 조정
      if (_savedBookmarkIndex != null &&
          (_savedBookmarkIndex! < 0 ||
              _savedBookmarkIndex! >= _wordList.length)) {
        setState(() {
          _currentIndex = 0;
          _savedBookmarkIndex = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다.\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.level}_bookmark';
    final idx = prefs.getInt(key);
    if (!mounted) return;
    if (idx != null &&
        _wordList.isNotEmpty &&
        idx >= 0 &&
        idx < _wordList.length) {
      setState(() {
        _savedBookmarkIndex = idx;
        _currentIndex = idx; // jump to last saved word
      });
    }
  }

  Future<void> _saveBookmark() async {
    if (_wordList.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '${widget.level}_bookmark';

    // 현재 단어가 이미 책갈피에 저장되어 있는지 확인
    if (_savedBookmarkIndex == _currentIndex) {
      // 이미 저장되어 있다면 제거
      await prefs.remove(key);
      if (!mounted) return;
      setState(() {
        _savedBookmarkIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('책갈피가 해제되었습니다.')),
      );
    } else {
      // 저장되어 있지 않다면 현재 인덱스를 저장
      await prefs.setInt(key, _currentIndex);
      if (!mounted) return;
      setState(() {
        _savedBookmarkIndex = _currentIndex;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 단어가 책갈피에 저장되었습니다.')),
      );
    }
  }

  // ------------------------------ TTS ------------------------------
  Future<void> _initTts() async {
    try {
      // Handlers
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

      // Try a few common English locales
      final langs = ['en-US', 'en-GB', 'en-AU', 'en'];
      for (final l in langs) {
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
      final t = _preprocessText(text);
      await _tts.speak(t);
    } catch (e) {
      debugPrint('Speak failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 재생 중 오류가 발생했습니다.')),
      );
    }
  }

  // ------------------------------ Controls ------------------------------
  void _nextWord({bool isAuto = false}) {
    if (_wordList.isEmpty || !mounted) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % _wordList.length;
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
    _autoPlayTimer =
        Timer.periodic(Duration(seconds: _autoPlayInterval), (timer) {
      if (_isAutoPlay) _nextWord(isAuto: true);
    });
  }

  void _previousWord() {
    if (_wordList.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _wordList.length) % _wordList.length;
    });
  }

  void _quickMoveForward() {
    if (_wordList.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + _quickMoveStep) % _wordList.length;
    });
  }

  void _quickMoveBackward() {
    if (_wordList.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - _quickMoveStep + _wordList.length) %
          _wordList.length;
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
  // 예문 내 단어를 강조하는 위젯 생성 함수
  Widget _buildHighlightedText({
    required String fullText,
    required TextStyle defaultStyle,
    required Set<String> subjectWords,
    required Set<String> verbWords,
  }) {
    if (fullText.isEmpty) {
      return Text(fullText, style: defaultStyle, textAlign: TextAlign.center);
    }

    final allTargets = {
      ...subjectWords,
      ...verbWords,
    }
        .where((w) => w.isNotEmpty)
        .map((w) => r'\b' + RegExp.escape(w) + r'\b')
        .join('|');

    if (allTargets.isEmpty) {
      return Text(fullText, style: defaultStyle, textAlign: TextAlign.center);
    }

    final pattern = RegExp('($allTargets)', caseSensitive: false);
    final List<InlineSpan> spans = [];

    fullText.splitMapJoin(
      pattern,
      onMatch: (m) {
        final originalWord = m.group(0)!;
        final word = originalWord.toLowerCase();

        TextStyle style = defaultStyle.copyWith(fontWeight: FontWeight.bold);

        final isSubject = subjectWords.contains(word);
        final isVerb = verbWords.contains(word);

        // 명사(주어)는 주황색 배경
        if (isSubject) {
          style = style.copyWith(
              backgroundColor: const Color.fromARGB(255, 190, 220, 255));
        }

        // 동사는 연한 노란색 배경
        if (isVerb) {
          style = style.copyWith(
              backgroundColor: const Color.fromARGB(255, 190, 235, 200));
        }

        spans.add(TextSpan(text: originalWord, style: style));
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

  // ------------------------------ UI ------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildScaffold(const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _buildScaffold(Center(child: Text('오류: $_error')));
    }
    if (_wordList.isEmpty) {
      return _buildScaffold(const Center(child: Text('단어 목록이 비어 있습니다.')));
    }

    final w = _wordList[_currentIndex];
    final showMeaning = _showMeaning || _alwaysShowMeaning;
    final isBookmarked = _savedBookmarkIndex == _currentIndex;

    // subjectWords와 verbWords 설정
    Set<String> subjectWords = {};
    if (w.subject != null) {
      subjectWords.add(w.subject!.toLowerCase());
    }

    Set<String> verbWords = {};
    if (w.verb != null) {
      verbWords.add(w.verb!.toLowerCase());
    }

    return _buildScaffold(
      Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 24.h),

              // Top: progress + always-show switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        '${widget.level} (${_currentIndex + 1}/${_wordList.length})',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '뜻 항상 보기',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _alwaysShowMeaning,
                            onChanged: (value) => _toggleAlwaysShowMeaning(),
                            activeThumbColor: _primary,
                          )),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _wordList.length,
                  minHeight: 10.h,
                  backgroundColor: Colors.grey.shade200,
                  color: _primary,
                ),
              ),

              SizedBox(height: 12.h),

              // Card (stack to overlay bookmark button)
              SizedBox(
                height: 280.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                        child: Column(
                          children: [
                            // Word content
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          w.word,
                                          style: TextStyle(
                                              fontSize: 28.sp,
                                              fontWeight: FontWeight.bold,
                                              color: _textDark),
                                        ),
                                        SizedBox(width: 8.w),
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20.r),
                                          onTap: () => _speak(w.word),
                                          child: Padding(
                                            padding: EdgeInsets.all(6.w),
                                            child: Icon(Icons.volume_up,
                                                color: _primary, size: 22.sp),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      '[ ${w.pronunciation.replaceAll(RegExp(r'\s'), '')} ]',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        color: Colors.blueGrey,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: showMeaning
                                          ? Column(
                                              key: const ValueKey('meaning'),
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      '(${w.partOfSpeech})',
                                                      style: TextStyle(
                                                        fontSize: 18.sp,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.blueGrey,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Flexible(
                                                      child: Text(
                                                        w.meaning,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 20.sp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: _textDark,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (w.example.isNotEmpty) ...[
                                                  SizedBox(height: 16.h),
                                                  Container(
                                                    height: 1,
                                                    width: 220.w,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                  SizedBox(height: 10.h),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child:
                                                            _buildHighlightedText(
                                                          fullText: w.example,
                                                          subjectWords: {
                                                            w.subject
                                                                    ?.toLowerCase() ??
                                                                '',
                                                          },
                                                          verbWords: {
                                                            w.verb?.toLowerCase() ??
                                                                ''
                                                          },
                                                          defaultStyle:
                                                              TextStyle(
                                                            fontSize: 16.sp,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                Color.fromARGB(
                                                                    255,
                                                                    0,
                                                                    0,
                                                                    0),
                                                            fontStyle: FontStyle
                                                                .normal,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 6.w),
                                                      InkWell(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16.r),
                                                        onTap: () =>
                                                            _speak(w.example),
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  4.w),
                                                          child: Icon(
                                                              Icons.volume_up,
                                                              size: 22.sp,
                                                              color: _primary),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (w.exampleMeaning
                                                      .isNotEmpty)
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 6.h),
                                                      child: Text(
                                                        w.exampleMeaning,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                            fontSize: 16.sp,
                                                            color: Colors
                                                                .blueGrey),
                                                      ),
                                                    ),
                                                ],
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bookmark button
                    Positioned(
                      top: -6.h,
                      left: -6.w,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.r),
                          onTap: _saveBookmark,
                          child: Padding(
                            padding: EdgeInsets.all(6.w),
                            child: Icon(
                              isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isBookmarked ? Colors.orange : Colors.grey,
                              size: 28.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),

              // 10개씩 이동 컨트롤 (카드 바깥으로 분리)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.fast_rewind,
                        size: 24.sp, color: Colors.grey),
                    onPressed: _quickMoveBackward,
                  ),
                  DropdownButton<int>(
                    value: _quickMoveStep,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 16.sp, color: _textDark),
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
                  IconButton(
                    icon: Icon(Icons.fast_forward,
                        size: 24.sp, color: Colors.grey),
                    onPressed: _quickMoveForward,
                  ),
                ],
              ),

              SizedBox(height: 8.h),

              // 뜻 보기 - '나중에 복습'과 같은 작고 은은한 컨셉으로 축소
              TextButton.icon(
                onPressed: _alwaysShowMeaning ? null : _toggleMeaning,
                icon: Icon(
                  _showMeaning ? Icons.visibility_off : Icons.visibility,
                  size: 16.sp,
                  color: _alwaysShowMeaning ? Colors.grey : _primary,
                ),
                label: Text(
                  _showMeaning ? '뜻 숨기기' : '뜻 보기',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _alwaysShowMeaning ? Colors.grey : _primary,
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              // Prev / Next
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: _previousWord,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: BorderSide(color: _primary),
                      padding: EdgeInsets.symmetric(
                          horizontal: 30.w, vertical: 20.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('이전 단어',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: _nextWord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: EdgeInsets.symmetric(
                          horizontal: 30.w, vertical: 20.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('다음 단어',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              SizedBox(height: 15.h),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isAutoPlay ? '자동모드' : '수동모드',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 20), //텍스트와 스위치 간격
                    Theme(
                      data: Theme.of(context).copyWith(
                        switchTheme: SwitchThemeData(
                          trackColor: WidgetStateProperty.resolveWith((states) {
                            return states.contains(WidgetState.selected)
                                ? const Color.fromARGB(255, 255, 177, 177)
                                : const Color.fromARGB(255, 212, 212, 212);
                          }),
                          thumbColor: WidgetStateProperty.all(Colors.white),
                        ),
                      ),
                      child: Transform.scale(
                        scale: 0.8, // 크기 조정 (숫자를 바꾸세요)
                        child: Switch(
                          value: _isAutoPlay,
                          onChanged: (_) => _toggleAutoPlay(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    DropdownButtonHideUnderline(
                      // 1. 밑줄 제거
                      child: DropdownButton<int>(
                        value: _autoPlayInterval,
                        elevation: 0, // 2. 그림자 제거
                        focusColor: Colors.transparent, // 3. 클릭 시 음영 제거
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black, // 평소 글자색
                          fontWeight: FontWeight.bold,
                        ),
                        // 4. 선택되었을 때의 디자인
                        selectedItemBuilder: (BuildContext context) {
                          return [5, 10, 20].map((int value) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$value초',
                                style: const TextStyle(
                                  color:
                                      Colors.black, // ★ 선택됐을 때 글자색 (원하는 색으로 변경)
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        items: [5, 10, 20]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text('$v초')))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _autoPlayInterval = v!);
                          if (_isAutoPlay) _startTimer();
                          FocusManager.instance.primaryFocus
                              ?.unfocus(); // 5. 클릭 후 포커스 해제 (음영 잔상 제거)
                        },
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 25.h),

              Center(
                child: SizedBox(
                  height: 50,
                  child: const CoupangBanner(),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _buildScaffold(Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.level} 단어 공부'),
        backgroundColor: Colors.transparent,
        foregroundColor: _textDark,
        titleTextStyle: TextStyle(
          color: _textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => SettingsPage(
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        )),
              );
            },
          ),
        ],
      ),
      body: body,
    );
  }
}
