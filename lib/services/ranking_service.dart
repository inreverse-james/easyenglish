// lib/services/ranking_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easyenglish/models/ranking_data.dart';

class RankingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CollectionReference<Map<String, dynamic>> _rankings =
      FirebaseFirestore.instance.collection('rankings');
  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');

  Future<String?> getUserId() async => FirebaseAuth.instance.currentUser?.uid;

  Future<String?> getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email;
  }

  /// 현재 로그인된 사용자의 닉네임을 users/{uid} 문서에 동기화합니다.
  /// 이걸 해둬야 닉네임을 바꿨을 때 "기존" 랭킹 기록에도 즉시 반영됩니다
  /// (기록 하나하나에 박힌 옛날 이름이 아니라, 이 최신 닉네임을 보여주기 때문).
  Future<void> syncUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final uid = user.uid;

    await _users.doc(uid).set({
      'uid': uid,
      'email': user.email,
      'nickname': user.displayName ?? '사용자',
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'isAnonymous': user.isAnonymous,
      'isEmailVerified': user.emailVerified,
      'isPhoneVerified': false,
      'authProvider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'unknown',
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addRanking(RankingData ranking) async {
    final uid = await getUserId();
    if (uid == null) return;

    // 시험 기록을 남길 때마다 최신 닉네임도 함께 동기화해둡니다.
    await syncUserProfile();

    await _rankings.add({
      'userId': uid,
      'userName': ranking.userName, // 그 시점의 이름을 기록으로도 남겨둠 (이력용)
      'correctAnswers': ranking.correctAnswers,
      'totalQuestions': ranking.totalQuestions,
      'accuracy': ranking.accuracy,
      'testDate': Timestamp.fromDate(ranking.testDate),
      'level': ranking.level,
    });
  }

  /// 사용자별 누적 랭킹 조회.
  /// 표시 이름은 users/{uid}의 "현재" 닉네임을 우선 사용하고,
  /// 혹시 그 문서가 없는 예외적인 경우에만 마지막 시험 기록의 이름으로 대체합니다.
  Future<List<RankingData>> getAggregatedRankings(
      {int recordLimit = 1000}) async {
    final snapshot = await _rankings
        .orderBy('testDate', descending: true)
        .limit(recordLimit)
        .get();

    final Map<String, _UserAgg> agg = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['userId'] as String? ?? '';
      if (uid.isEmpty) continue;

      final correct = data['correctAnswers'] as int? ?? 0;
      final total = data['totalQuestions'] as int? ?? 0;
      final name = data['userName'] as String? ?? '사용자';
      final testDate =
          (data['testDate'] as Timestamp?)?.toDate() ?? DateTime.now();

      final existing = agg[uid];
      if (existing == null) {
        agg[uid] = _UserAgg(
          fallbackName: name,
          correctSum: correct,
          totalSum: total,
          testCount: 1,
          lastTestDate: testDate,
        );
      } else {
        existing.correctSum += correct;
        existing.totalSum += total;
        existing.testCount += 1;
        if (testDate.isAfter(existing.lastTestDate)) {
          existing.fallbackName = name;
          existing.lastTestDate = testDate;
        }
      }
    }

    final results = <RankingData>[];
    for (final entry in agg.entries) {
      final uid = entry.key;
      final v = entry.value;

      String displayName = v.fallbackName;
      try {
        final userDoc = await _users.doc(uid).get();
        final liveName = userDoc.data()?['nickname'] as String?;
        if (liveName != null && liveName.isNotEmpty) {
          displayName = liveName;
        }
      } catch (_) {
        // users 문서가 없거나 조회 실패해도 fallback 이름으로 계속 진행
      }

      results.add(RankingData(
        userId: uid,
        userName: displayName,
        correctAnswers: v.correctSum,
        totalQuestions: v.totalSum,
        accuracy: v.totalSum == 0 ? 0 : v.correctSum / v.totalSum,
        testDate: v.lastTestDate,
        level: '${v.testCount}회 응시',
      ));
    }

    results.sort((a, b) {
      // 1. 정답률
      int result = b.accuracy.compareTo(a.accuracy);
      if (result != 0) return result;

      // 2. 맞힌 개수
      result = b.correctAnswers.compareTo(a.correctAnswers);
      if (result != 0) return result;

      // 3. 최근 시험일
      return b.testDate.compareTo(a.testDate);
    });

    return results;
  }

  /// 현재 로그인된 사용자 본인의 기록만 삭제합니다.
  Future<void> clearRankings() async {
    final uid = await getUserId();
    if (uid == null) return;
    final mine = await _rankings.where('userId', isEqualTo: uid).get();
    final batch = _db.batch();
    for (final doc in mine.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

class _UserAgg {
  String fallbackName;
  int correctSum;
  int totalSum;
  int testCount;
  DateTime lastTestDate;
  _UserAgg({
    required this.fallbackName,
    required this.correctSum,
    required this.totalSum,
    required this.testCount,
    required this.lastTestDate,
  });
}
