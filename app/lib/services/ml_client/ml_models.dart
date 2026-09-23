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
    required this.weather,
    required this.operatorSkill,
    required this.machineAgeYears, // required by the backend contract
    this.vertical = 'construction',
    this.materialType,
    this.haulDistanceM,
    // where + when: use the live weather forecast for the ETA
    this.siteId,
    this.latitude,
    this.longitude,
    this.startTime,
    // weather the app already has (overrides the forecast)
    this.temperatureC,
    this.humidityPct,
    this.windSpeedKmh,
    this.visibilityM,
    this.precipMmH,
    this.suggestStart = false,
  });

  final String taskType;
  final String weather;
  final String operatorSkill;
  final double machineAgeYears;
  final String vertical;
  final String? materialType;
  final double? haulDistanceM;
  final String? siteId;
  final double? latitude;
  final double? longitude;
  final DateTime? startTime;
  final double? temperatureC;
  final double? humidityPct;
  final double? windSpeedKmh;
  final double? visibilityM;
  final double? precipMmH;
  final bool suggestStart;

  Map<String, dynamic> toJson() => {
    'task_type': taskType,
    'weather': weather,
    'operator_skill': operatorSkill,
    'machine_age_yrs': machineAgeYears,
    'vertical': vertical,
    if (materialType != null) 'material_type': materialType,
    if (haulDistanceM != null) 'haul_distance_m': haulDistanceM,
    if (siteId != null) 'site_id': siteId,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (startTime != null) 'start_time': startTime!.toIso8601String(),
    if (temperatureC != null) 'temperature_c': temperatureC,
    if (humidityPct != null) 'humidity_pct': humidityPct,
    if (windSpeedKmh != null) 'wind_speed_kmh': windSpeedKmh,
    if (visibilityM != null) 'visibility_m': visibilityM,
    if (precipMmH != null) 'precip_mm_h': precipMmH,
    if (suggestStart) 'suggest_start': true,
  };
}

/// One line of the ETA explanation (minutes added/removed vs the baseline).
class EtaFactor {
  const EtaFactor({required this.name, required this.minutes, required this.detail});

  factory EtaFactor.fromJson(Map<String, dynamic> j) => EtaFactor(
    name: j['name'] as String? ?? '',
    minutes: (j['minutes'] as num?)?.toDouble() ?? 0,
    detail: j['detail'] as String? ?? '',
  );

  final String name;
  final double minutes;
  final String detail;
}

/// A suggested better start time in the next 24 h (from `suggest_start`).
class BestStart {
  const BestStart({
    required this.startTime,
    required this.estimatedMinutes,
    required this.minutesSaved,
    required this.reason,
  });

  factory BestStart.fromJson(Map<String, dynamic> j) => BestStart(
    startTime: j['start_time'] as String? ?? '',
    estimatedMinutes: (j['estimated_minutes'] as num?)?.toDouble() ?? 0,
    minutesSaved: (j['minutes_saved'] as num?)?.toDouble() ?? 0,
    reason: j['reason'] as String? ?? '',
  );

  final String startTime;
  final double estimatedMinutes;
  final double minutesSaved;
  final String reason;
}

class EstimateResponse {
  const EstimateResponse({
    required this.estimatedMinutes,
    this.baselineMinutes,
    this.modelVersion = 'stub-0',
    this.weatherSource,
    this.factors = const [],
    this.advisories = const [],
    this.bestStart,
  });

  factory EstimateResponse.fromJson(Map<String, dynamic> json) {
    // `estimated_minutes` is the backend field; keep `predicted_minutes` as a
    // fallback so an older stub still parses.
    final minutes = json['estimated_minutes'] ?? json['predicted_minutes'];
    final bs = json['best_start'];
    return EstimateResponse(
      estimatedMinutes: (minutes as num).toDouble(),
      baselineMinutes: (json['baseline_minutes'] as num?)?.toDouble(),
      modelVersion: json['model_version'] as String? ?? 'stub-0',
      weatherSource: json['weather_source'] as String?,
      factors: ((json['factors'] as List?) ?? const [])
          .map((e) => EtaFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
      advisories: List<String>.from((json['advisories'] as List?) ?? const []),
      bestStart: bs is Map<String, dynamic> ? BestStart.fromJson(bs) : null,
    );
  }

  final double estimatedMinutes;
  final double? baselineMinutes;
  final String modelVersion;
  final String? weatherSource;
  final List<EtaFactor> factors;
  final List<String> advisories;
  final BestStart? bestStart;
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
