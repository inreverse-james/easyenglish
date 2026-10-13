import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/theme/app_theme.dart';
import 'package:easyenglish/pages/settings_page.dart';
import 'package:easyenglish/pages/word_study_page.dart';
import 'package:easyenglish/services/word_data_service.dart';
import 'package:easyenglish/widgets/coupang_banner.dart';

class LevelSelectPage extends StatefulWidget {
  const LevelSelectPage({super.key});

  @override
  State<LevelSelectPage> createState() => _LevelSelectPageState();
}

class _LevelSelectPageState extends State<LevelSelectPage> {
  final WordDataService _wordDataService = WordDataService();

  // 레벨별 이모지 / 영문 설명 (레벨 순서대로 사용)
  static const List<String> _emojis = ['🌱', '🌿', '🌳', '⛰️', '🏅'];
  static const List<String> _subs = [
    'Beginner Level',
    'Elementary Level',
    'Intermediate Level',
    'Advanced Level',
    'Master Level',
  ];

  List<String> _levels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLevels();
  }

  Future<void> _fetchLevels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final levels = await _wordDataService.fetchLevels();
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '단어 목록을 불러오지 못했어요.\n인터넷 연결을 확인하고 다시 시도해 주세요.';
        _isLoading = false;
      });
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 44.sp, color: AppColors.textSecondary),
              SizedBox(height: 16.h),
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
                onPressed: _fetchLevels,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLevels,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        children: [
          // 상단 헤더: 큰 제목 + 설정 버튼
          Row(
            children: [
              Expanded(
                child: Text(
                  'Easy English',
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: '설정',
                onPressed: _openSettings,
                icon: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings_outlined,
                      size: 20.sp, color: AppColors.primary),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            '오늘도 꾸준히 학습해봐요 👋',
            style: TextStyle(
              fontSize: 15.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 28.h),

          // 섹션 제목
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
            child: Text(
              '학습 레벨',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          if (_levels.isEmpty)
            _buildEmptyCard()
          else
            _buildLevelList(),

          SizedBox(height: 24.h),

          // 광고 배너
          Center(
            child: SizedBox(
              height: 50,
              child: const CoupangBanner(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        '불러올 단어 레벨이 없어요.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15.sp, color: AppColors.textSecondary),
      ),
    );
  }

  // 한 장의 흰 카드 안에 레벨들이 얇은 선으로 구분되어 나열됩니다.
  Widget _buildLevelList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_levels.length, (i) {
          final isLast = i == _levels.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WordStudyPage(level: _levels[i]),
                    ),
                  );
                },
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  child: Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _emojis[i % _emojis.length],
                          style: TextStyle(fontSize: 22.sp),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _levels[i],
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _subs[i % _subs.length],
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 24.sp, color: const Color(0xFFC7C7CC)),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: EdgeInsets.only(left: 74.w),
                  child: const Divider(),
                ),
            ],
          );
        }),
      ),
    );
  }
}
