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
  // 소프트 라벤더 톤 컬러
  static const Color _primary = Color(0xFF8D85D6);
  static const List<Color> _primaryGradient = [
    Color(0xFFA99FEE),
    Color(0xFF8D85D6)
  ];
  static const Color _primaryLight = Color(0xFFF3F1FC);
  static const Color _textDark = Color(0xFF2B2A33);
  static const Color _textMuted = Color(0xFFADAABD);

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
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
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
        title: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 16)),
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
            SizedBox(height: 10.h),
            Text(
              "📚 학습 레벨 선택",
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF4A4758),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            ...List.generate(levels.length, (i) {
              final selected = i == -1;

              // 레벨별 이모지 - 요청하신 이미지 그대로 실제 이모지 글자로 구현
              final emojis = ['🌱', '🌿', '🌳', '⛰️', '🏅'];

              final subs = [
                "Beginner Level",
                "Elementary Level",
                "Intermediate Level",
                "Advanced Level",
                "Master Level"
              ];

              return Container(
                margin: EdgeInsets.only(bottom: 7.h),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(colors: _primaryGradient)
                      : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: selected
                      ? null
                      : Border.all(color: const Color(0xFFF0EFF6)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 2.h,
                  ),
                  leading: Container(
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : _primaryLight,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emojis[i % emojis.length],
                      style: TextStyle(fontSize: 15.sp),
                    ),
                  ),
                  title: Text(
                    levels[i],
                    style: TextStyle(
                      color: selected ? Colors.white : _textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5.sp,
                    ),
                  ),
                  subtitle: Text(
                    subs[i % subs.length],
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: selected ? Colors.white70 : _textMuted,
                    ),
                  ),
                  trailing: Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xFFF5F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: selected ? Colors.white : _primary,
                      size: 16.sp,
                    ),
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
                color: const Color(0xFF4A4758),
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
                    Color.fromARGB(255, 207, 201, 250),
                    Color.fromARGB(255, 167, 160, 226),
                    Color.fromARGB(255, 162, 154, 228),
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
                  side: const BorderSide(color: Color(0xFFE7E4F5)),
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
              color: const Color(0xFFC7C4D6), size: 16.sp),
          style: TextStyle(
            fontSize: 12.5.sp,
            color: const Color(0xFF4A4758),
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
