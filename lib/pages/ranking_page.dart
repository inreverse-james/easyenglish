import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/models/ranking_data.dart';
import 'package:easyenglish/services/ranking_service.dart';
import 'package:easyenglish/pages/level_select_page.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key, required this.userId});
  final String userId;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  // level_select_page와 동일한 소프트 라벤더 톤으로 통일
  static const Color _primary = Color(0xFF8D85D6);
  static const Color _primaryLight = Color(0xFFF3F1FC);
  static const Color _textDark = Color(0xFF2B2A33);

  final RankingService _rankingService = RankingService();
  List<RankingData> _rankingList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRankingList();
  }

  Future<void> _loadRankingList() async {
    setState(() => _isLoading = true);
    final list = await _rankingService.getAggregatedRankings();
    if (!mounted) return;
    setState(() {
      _rankingList = list;
      _isLoading = false;
    });
  }

  Future<void> _clearRankings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 랭킹 기록 초기화'),
        content: const Text(
          '내가 남긴 기록만 모두 삭제됩니다.\n다른 사용자의 기록에는 영향이 없어요.\n계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _rankingService.clearRankings();
        await _loadRankingList();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내 랭킹 기록을 초기화했습니다.'),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
          ),
        );
      }
    }
  }

  // 1~3위는 메달 색, 그 외는 순번 텍스트
  Widget _buildRankBadge(int rank) {
    const medalColors = {
      1: Color(0xFFFFC107), // 금
      2: Color(0xFFB0BEC5), // 은
      3: Color(0xFFCD7F32), // 동
    };

    if (medalColors.containsKey(rank)) {
      return CircleAvatar(
        radius: 12.r,
        backgroundColor: medalColors[rank],
        child: Text(
          '$rank',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.sp,
          ),
        ),
      );
    }

    return SizedBox(
      width: 24.w,
      child: Text(
        '$rank.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
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
              "랭킹 순위",
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Container(
            width: 30.w,
            height: 30.w,
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.home, color: _primary, size: 16.sp),
          ),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => LevelSelectPage(userId: widget.userId),
              ),
              (route) => false,
            );
          },
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
              child: Icon(Icons.delete_forever, color: _primary, size: 16.sp),
            ),
            tooltip: '내 기록 초기화',
            onPressed: _clearRankings,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _rankingList.isEmpty
              ? Center(
                  child: Text(
                    '아직 랭킹 기록이 없습니다.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15.sp),
                  ),
                )
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadRankingList,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount:
                        _rankingList.length > 20 ? 20 : _rankingList.length,
                    itemBuilder: (context, index) {
                      final ranking = _rankingList[index];
                      final rank = index + 1;

                      // 순위 · 이름 · 레벨 · 정답수 · 정확도를 한 줄로 압축
                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 3.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: const Color(0xFFF0EFF6)),
                        ),
                        child: Row(
                          children: [
                            _buildRankBadge(rank),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: 2.w),
                                child: Text(
                                  ranking.userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            ),
                            if (ranking.level.isNotEmpty) ...[
                              SizedBox(width: 12.w), // 원하는 간격
                              SizedBox(
                                width: 55.w, // 55~65 정도 취향대로
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primaryLight,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    ranking.level,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      color: _primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(width: 12.w),
                            Text(
                              '${ranking.correctAnswers}/${ranking.totalQuestions}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              '${(ranking.accuracy * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
