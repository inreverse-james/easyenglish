import 'package:flutter/material.dart';
import 'package:easyenglish/pages/settings_page.dart';
import 'package:easyenglish/pages/word_quiz_page.dart';
import 'package:easyenglish/pages/word_study_page.dart';
import 'package:easyenglish/pages/ranking_page.dart';
import '../services/word_data_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/widgets/coupang_banner.dart';

class LevelSelectPage extends StatefulWidget {
  final String userId;
  const LevelSelectPage({super.key, required this.userId});

  @override
  State<LevelSelectPage> createState() => _LevelSelectPageState();
}

class _LevelSelectPageState extends State<LevelSelectPage> {
  // 심플한 블루 & 화이트 컬러
  static const Color _primary = Color(0xFF1769FF);
  static const List<Color> _primaryGradient = [
    Color(0xFF3984FF),
    Color(0xFF1769FF)
  ];
  static const Color _primaryLight = Color(0xFFEEF4FF);
  static const Color _textDark = Color(0xFF172033);
  static const Color _textMuted = Color(0xFF8792A5);

  final WordDataService _wordDataService = WordDataService();

  List<String> levels = [];
  String? selectedQuizLevel;
  int selectedQuizCount = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLevels();
  }

  Future<void> _fetchLevels() async {
    setState(() => _isLoading = true);

    final availableLevels = await _wordDataService.fetchLevels();

    if (mounted) {
      setState(() {
        levels = availableLevels;
        selectedQuizLevel = levels.isNotEmpty ? levels.first : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(color: Colors.white),
        title: Row(
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(8.r),
              ),
              alignment: Alignment.center,
              child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20.sp)),
            ),
            SizedBox(width: 8.w),
            Text(
              "English Study",
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              width: 30.w,
              height: 30.w,
              decoration: const BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.settings_outlined, color: _primary, size: 16.sp),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(userId: widget.userId),
                ),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Welcome 👋",
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    "오늘도 꾸준히 학습해봐요!",
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ...List.generate(levels.length, (i) {
              final selected = i == -1; // 선택된 상태 로직은 유지

              final emojis = ['🌱', '🌿', '🌳', '⛰️', '🏅'];
              final subs = [
                "Beginner Level",
                "Elementary Level",
                "Intermediate Level",
                "Advanced Level",
                "Master Level"
              ];

              return Container(
                margin: EdgeInsets.only(bottom: 12.h), // 간격 넓힘
                decoration: BoxDecoration(
                  gradient: selected ? const LinearGradient(colors: _primaryGradient) : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20.r), // 모서리 더 둥글게
                  // 테두리(border) 제거하고 그림자(boxShadow) 적용
                  boxShadow: selected ? [
                     BoxShadow(
                        color: _primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                  ] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  leading: Container(
                    width: 44.w, // 크기 키움
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.22) : _primaryLight,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emojis[i % emojis.length],
                      style: TextStyle(fontSize: 20.sp), // 이모지 크기 키움
                    ),
                  ),
                  title: Text(
                    levels[i],
                    style: TextStyle(
                      color: selected ? Colors.white : _textDark,
                      fontWeight: FontWeight.w800, // 굵기 강조
                      fontSize: 15.sp,
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      subs[i % subs.length],
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white70 : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: selected ? Colors.white : Colors.grey.shade400,
                    size: 24.sp,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WordStudyPage(level: levels[i]),
                      ),
                    );
                  },
                ),
              );
            }),
            SizedBox(height: 2.h),
            Divider(
              thickness: 1,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 2.h),
            Center(
              child: SizedBox(
                height: 50,
                child: const CoupangBanner(),
              ),
            ),
            SizedBox(height: 2.h),
            Divider(
              thickness: 1,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 2.h),
            Text(
              "📝 단어 시험 선택",
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF344054),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    levels,
                    selectedQuizLevel,
                    (v) => setState(() {
                      selectedQuizLevel = v;
                    }),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _buildDropdown(
                    [10, 20, 30, 40, 50],
                    selectedQuizCount,
                    (v) => setState(() {
                      selectedQuizCount = v;
                    }),
                    isInt: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              height: 50.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999.r),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3984FF),
                    Color(0xFF1769FF),
                    Color(0xFF1769FF),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x338D85D6),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WordQuizPage(
                        userId: widget.userId,
                        levels: [selectedQuizLevel!],
                        quizCount: selectedQuizCount,
                      ),
                    ),
                  );
                },
                child: Text(
                  "단어 시험 시작 🚀",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 9.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD6E4FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RankingPage(
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
                child: Text("단어 시험 랭킹 보기 🏆",
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(List items, var value, Function(dynamic) onChanged,
      {bool isInt = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFEDECF5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more,
              color: const Color(0xFF98A2B3), size: 16.sp),
          style: TextStyle(
            fontSize: 12.5.sp,
            color: const Color(0xFF344054),
            fontWeight: FontWeight.w500,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    isInt ? "$e문제" : e,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
