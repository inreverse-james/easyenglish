import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easyenglish/pages/level_select_page.dart';
import 'package:easyenglish/models/quiz_models.dart';
import 'package:easyenglish/pages/ranking_page.dart';

class QuizResultPage extends StatelessWidget {
  final List<WordQuizAnswer> quizAnswers;
  final int correctAnswers;
  final int totalQuestions;
  final List<String> levels;
  final String userId; // 생성자 매개변수로 userId를 받습니다.

  static const Color _primary = Color(0xFF8D85D6);
  static const Color _primaryLight = Color(0xFFF3F1FC);
  static const Color _textDark = Color(0xFF2B2A33);

  const QuizResultPage({
    super.key,
    required this.quizAnswers,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.levels,
    required this.userId, // 매개변수 이름을 일치시킵니다.
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            const Text('📝', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8.w),
            Text(
              "시험 결과",
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
            child: Icon(Icons.close, color: _primary, size: 16.sp),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(userId),
            SizedBox(height: 16.h),
            _buildSectionTitle('문제 리뷰'),
            SizedBox(height: 8.h),
            _buildSequentialReviewList(),
            SizedBox(height: 16.h),
            _buildButtonRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String userId) {
    final double accuracy = (correctAnswers / totalQuestions) * 100;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0EFF6)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              '$userId님의 시험 결과',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetric('정확도', '${accuracy.toStringAsFixed(1)}%',
                    Colors.green.shade600),
                _buildMetric(
                    '정답', correctAnswers.toString(), _primary),
                _buildMetric('오답', (totalQuestions - correctAnswers).toString(),
                    Colors.red.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSequentialReviewList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0EFF6)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: quizAnswers.length,
          itemBuilder: (context, index) {
            final answer = quizAnswers[index];
            final questionNumber = index + 1;

            return Container(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: index < quizAnswers.length - 1
                      ? BorderSide(color: Colors.grey.shade200, width: 0.5)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34.w,
                    height: 18.h,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 16.w,
                          child: Text(
                            '$questionNumber.',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!answer.isCorrect)
                          Positioned(
                            top: -3.h,
                            left: 0,
                            child: Text(
                              '✗',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ),
                        if (answer.isCorrect)
                          Positioned(
                            top: -3.h,
                            left: 0,
                            child: Text(
                              '○',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: answer.word.word,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              backgroundColor: Colors.grey.shade200,
                              color: Colors.black87,
                            ),
                          ),
                          const TextSpan(text: ' - '),
                          TextSpan(
                            text: answer.selectedAnswer,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: answer.isCorrect
                                  ? Colors.black87
                                  : Colors.red.shade600,
                            ),
                          ),
                          if (!answer.isCorrect) ...[
                            const TextSpan(
                              text: ' (정답: ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextSpan(
                              text: answer.word.meaning,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const TextSpan(
                              text: ')',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildButtonRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildRankingButton(context)),
        SizedBox(width: 10.w),
        Expanded(child: _buildHomeButton(context)),
      ],
    );
  }

  Widget _buildRankingButton(BuildContext context) {
    return SizedBox(
      height: 50.h,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RankingPage(userId: userId),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999.r),
          ),
        ),
        child: Text(
          '랭킹 보기',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    return SizedBox(
      height: 50.h,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => LevelSelectPage(userId: userId)),
            (route) => false,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: BorderSide(color: _primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999.r),
          ),
        ),
        child: Text(
          '홈으로 돌아가기',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}