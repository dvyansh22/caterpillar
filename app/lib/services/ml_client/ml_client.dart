/// Dio-based client for the FastAPI ML backend.
///
/// Returns stub/mock responses when backend is unreachable (offline-first).
/// Consumes: `/ml/estimate`, `/ml/anomaly`, `/rag/query`.
/// Contract: P1/P2 → P3 (AGENTS.md interface contract #1).
library;

import 'package:dio/dio.dart';

import '../../core/config.dart';
import 'ml_models.dart';

class MlClient {
  MlClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ));

  final Dio _dio;

  // -------------------------------------------------------------------------
  // Task-time estimation
  // -------------------------------------------------------------------------

  /// Request a task-time ETA from the ML model.
  /// Falls back to a stub response if the backend is unreachable.
  Future<EstimateResponse> getEstimate(EstimateRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ml/estimate',
        data: request.toJson(),
      );
      return EstimateResponse.fromJson(response.data!);
    } catch (_) {
      // Offline fallback — return a plausible stub.
      return const EstimateResponse(
        estimatedMinutes: 45.0,
        baselineMinutes: 60.0,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Anomaly / behavior scoring
  // -------------------------------------------------------------------------

  /// Request an anomaly/behavior score.
  Future<AnomalyResponse> getAnomalyScore(AnomalyRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ml/anomaly',
        data: request.toJson(),
      );
      return AnomalyResponse.fromJson(response.data!);
    } catch (_) {
      return const AnomalyResponse(
        anomalyScore: 0.15,
        isAnomaly: false,
        reasons: [],
      );
    }
  }

  // -------------------------------------------------------------------------
  // RAG repair Q&A
  // -------------------------------------------------------------------------

  /// Ask a repair question answered from machine manuals via RAG.
  Future<RagQueryResponse> queryRag(RagQueryRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/rag/query',
        data: request.toJson(),
      );
      return RagQueryResponse.fromJson(response.data!);
    } catch (_) {
      return const RagQueryResponse(
        answer:
            'Unable to reach the repair knowledge base. Please check your '
            'network connection or consult the operator manual.',
        sources: [],
        confidence: 0.0,
      );
    }
  }

  /// Dispose the Dio client.
  void dispose() => _dio.close();
}
