/// Request/response Dart models for the FastAPI ML endpoints.
///
/// Must stay in sync with the pydantic schemas in
/// `backend/app/routers/ml.py` and `rag.py`.
/// Contract: P1/P2 → P3 (AGENTS.md interface contract #1).
library;

// ---------------------------------------------------------------------------
// /ml/estimate — Task-time estimation
// ---------------------------------------------------------------------------

class EstimateRequest {
  const EstimateRequest({
    required this.taskType,
    required this.machineType,
    required this.operatorSkill,
    required this.weather,
    this.vertical = 'construction',
    this.machineAgeYears,
    this.materialType,
    this.terrainSlope,
    this.temperatureC,
    this.windSpeed,
    this.haulDistanceM,
  });

  final String taskType;
  final String machineType;
  final String operatorSkill;
  final String weather;
  final String vertical;
  final double? machineAgeYears;
  final String? materialType;
  final double? terrainSlope;
  final double? temperatureC;
  final double? windSpeed;
  final double? haulDistanceM;

  Map<String, dynamic> toJson() => {
    'task_type': taskType,
    'machine_type': machineType,
    'operator_skill': operatorSkill,
    'weather': weather,
    'vertical': vertical,
    if (machineAgeYears != null) 'machine_age_yrs': machineAgeYears,
    if (materialType != null) 'material_type': materialType,
    if (terrainSlope != null) 'terrain_slope': terrainSlope,
    if (temperatureC != null) 'temperature_c': temperatureC,
    if (windSpeed != null) 'wind_speed': windSpeed,
    if (haulDistanceM != null) 'haul_distance_m': haulDistanceM,
  };
}

class EstimateResponse {
  const EstimateResponse({
    required this.predictedMinutes,
    required this.confidence,
    this.baselineMinutes,
  });

  factory EstimateResponse.fromJson(Map<String, dynamic> json) {
    // Tolerant to the backend field name: the P1 stub returns
    // `estimated_minutes`; a future model build may return `predicted_minutes`.
    final minutes = json['predicted_minutes'] ?? json['estimated_minutes'];
    return EstimateResponse(
      predictedMinutes: (minutes as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.75,
      baselineMinutes: (json['baseline_minutes'] as num?)?.toDouble(),
    );
  }

  final double predictedMinutes;
  final double confidence;
  final double? baselineMinutes;
}

// ---------------------------------------------------------------------------
// /ml/anomaly — Behavior / anomaly scoring
// ---------------------------------------------------------------------------

class AnomalyRequest {
  const AnomalyRequest({
    required this.machineId,
    required this.operatorId,
    required this.engineHours,
    required this.fuelUsedL,
    required this.idlingTimeMin,
    required this.loadCycles,
    this.seatbeltStatus = 'Fastened',
    this.speedKmh,
    this.harshEvents,
  });

  final String machineId;
  final String operatorId;
  final double engineHours;
  final double fuelUsedL;
  final double idlingTimeMin;
  final int loadCycles;
  final String seatbeltStatus;
  final double? speedKmh;
  final int? harshEvents;

  Map<String, dynamic> toJson() => {
    'machine_id': machineId,
    'operator_id': operatorId,
    'engine_hours': engineHours,
    'fuel_used_l': fuelUsedL,
    'idling_time_min': idlingTimeMin,
    'load_cycles': loadCycles,
    'seatbelt_status': seatbeltStatus,
    if (speedKmh != null) 'speed_kmh': speedKmh,
    if (harshEvents != null) 'harsh_events': harshEvents,
  };
}

class AnomalyResponse {
  const AnomalyResponse({
    required this.anomalyScore,
    required this.isAnomaly,
    required this.reasons,
  });

  factory AnomalyResponse.fromJson(Map<String, dynamic> json) {
    // Tolerant to the backend field names: the P2 stub returns `score` /
    // `anomaly`; an expanded contract may use `anomaly_score` / `is_anomaly`.
    final score = json['anomaly_score'] ?? json['score'];
    final flag = json['is_anomaly'] ?? json['anomaly'];
    return AnomalyResponse(
      anomalyScore: (score as num).toDouble(),
      isAnomaly: flag as bool,
      reasons: List<String>.from((json['reasons'] as List?) ?? const []),
    );
  }

  final double anomalyScore;
  final bool isAnomaly;
  final List<String> reasons;
}

// ---------------------------------------------------------------------------
// /rag/query — Repair Q&A
// ---------------------------------------------------------------------------

class RagQueryRequest {
  const RagQueryRequest({required this.question, this.machineModel, this.faultCode});

  final String question;
  final String? machineModel;
  final String? faultCode;

  Map<String, dynamic> toJson() => {
    'question': question,
    if (machineModel != null) 'machine_model': machineModel,
    if (faultCode != null) 'fault_code': faultCode,
  };
}

class RagQueryResponse {
  const RagQueryResponse({
    required this.answer,
    required this.sources,
    this.confidence,
  });

  factory RagQueryResponse.fromJson(Map<String, dynamic> json) {
    return RagQueryResponse(
      answer: json['answer'] as String,
      sources: List<String>.from(json['sources'] as List),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  final String answer;
  final List<String> sources;
  final double? confidence;
}
