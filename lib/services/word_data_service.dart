// lib/services/word_data_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word.dart';

class WordDataService {
  // 구글 시트 ID만 필요 (API 키 불필요!)
  static const String _sheetId = '1x-0l8-tIYUtMD0IxDasd86ZEOLATP-YVPQQV0E_6Ki4';
  static const String _csvUrl =
      'https://docs.google.com/spreadsheets/d/$_sheetId/export?format=csv&gid=0';

  // 캐시된 데이터
  Map<String, List<Word>>? _cachedWordList;
  DateTime? _lastFetchTime;
  static const Duration _cacheTimeout = Duration(minutes: 10);

  /// CSV 파싱 헬퍼 함수
  List<List<String>> _parseCsv(String csvString) {
    List<List<String>> csvTable = [];
    List<String> rows = csvString.split('\n');

    for (String row in rows) {
      if (row.trim().isNotEmpty) {
        // 간단한 CSV 파싱 (따옴표 처리 포함)
        List<String> fields = [];
        bool inQuotes = false;
        String currentField = '';

        for (int i = 0; i < row.length; i++) {
          String char = row[i];

          if (char == '"') {
            inQuotes = !inQuotes;
          } else if (char == ',' && !inQuotes) {
            fields.add(currentField.trim());
            currentField = '';
          } else {
            currentField += char;
          }
        }

        // 마지막 필드 추가
        fields.add(currentField.trim());
        csvTable.add(fields);
      }
    }

    return csvTable;
  }

  /// 전체 단어 데이터를 레벨별로 불러오기 (캐시 적용)
  Future<Map<String, List<Word>>> fetchWordList() async {
    // 캐시가 유효한지 확인
    if (_cachedWordList != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTimeout) {
      return _cachedWordList!;
    }

    try {
      final response = await http.get(Uri.parse(_csvUrl));

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      // UTF-8 디코딩으로 한글 깨짐 방지
      final csvData = _parseCsv(utf8.decode(response.bodyBytes));

      if (csvData.isEmpty) {
        return {};
      }

      final wordList = <String, List<Word>>{};

      // 첫 번째 행(헤더) 건너뛰기
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];

        // 최소 2개 컬럼(레벨, 단어)이 있어야 함
        if (row.length >= 2 && row[0].isNotEmpty && row[1].isNotEmpty) {
          try {
            final level = row[0].trim();
            if (level.isNotEmpty) {
              final word = Word.fromList(row);
              wordList.putIfAbsent(level, () => []);
              wordList[level]!.add(word);
            }
          } catch (e) {
            // 개별 행 파싱 오류는 로그만 남기고 계속 진행
            continue;
          }
        }
      }

      // 캐시 업데이트
      _cachedWordList = wordList;
      _lastFetchTime = DateTime.now();

      return wordList;
    } catch (e) {
      throw Exception('단어 목록을 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// 레벨 목록만 불러오기
  Future<List<String>> fetchLevels() async {
    try {
      final allData = await fetchWordList();
      final levels = allData.keys.toList();
      final order = ['입문', '초급', '중급', '상급', '최상급'];
      // 레벨 정렬 (숫자가 포함된 경우 자연 정렬)
      levels.sort((a, b) {
        
        // 숫자 추출해서 정렬
        int indexA = order.indexOf(a);
        int indexB = order.indexOf(b);

        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;
        
        return indexA.compareTo(indexB);
      });

      return levels;
    } catch (e) {
      throw Exception('레벨 목록을 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// 특정 레벨의 단어만 불러오기
  Future<List<Word>> getWordsForLevel(String level) async {
    try {
      final allData = await fetchWordList();
      return allData[level] ?? [];
    } catch (e) {
      throw Exception('레벨 "$level"의 단어를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// 여러 레벨의 단어들을 합쳐서 반환
  Future<List<Word>> getWordsForLevels(List<String> levels) async {
    try {
      final allData = await fetchWordList();
      final words = <Word>[];

      for (final level in levels) {
        final levelWords = allData[level] ?? [];
        words.addAll(levelWords);
      }

      return words;
    } catch (e) {
      throw Exception('여러 레벨의 단어를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  /// 캐시 초기화
  void clearCache() {
    _cachedWordList = null;
    _lastFetchTime = null;
  }

  /// 특정 단어 검색
  Future<List<Word>> searchWords(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final allData = await fetchWordList();
      final results = <Word>[];

      final queryLower = query.toLowerCase();

      for (final levelWords in allData.values) {
        for (final word in levelWords) {
          if (word.word.toLowerCase().contains(queryLower) ||
              word.meaning.toLowerCase().contains(queryLower)) {
            results.add(word);
          }
        }
      }

      return results;
    } catch (e) {
      throw Exception('단어 검색 중 오류가 발생했습니다: $e');
    }
  }

  /// 연결 테스트 (간단한 HEAD 요청)
  Future<bool> testConnection() async {
    try {
      final response = await http.head(Uri.parse(_csvUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
