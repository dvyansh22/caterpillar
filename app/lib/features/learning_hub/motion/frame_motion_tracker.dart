/// Real-time, on-device colour-marker tracker for the AR training lessons.
///
/// **No calibration.** Each module knows its marker colour (the gear controller
/// is red, the lever is blue), so the tracker is simply armed with a target hue
/// via [setTarget]. It then:
///   1. **Auto-acquires** — scans the whole frame for the densest blob of that
///      hue and locks on (no tap, no reticle).
///   2. **Tracks** — mean-shift over hue-matching pixels in a small window,
///      fused with frame-difference motion (the moving hand) to survive weak
///      locks. If the marker is lost, it re-acquires automatically.
///
/// Hue matching is done in HSV, so it is invariant to brightness/auto-exposure.
/// No ML model, no network. Coordinates returned are display-space (0–1).
/// Owner: P3 (FR-LEARN).
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';

/// A movement direction in the coordinate frame the user sees on screen.
enum MoveDir { forward, back, left, right, none }

extension MoveDirInfo on MoveDir {
  String get arrow => switch (this) {
        MoveDir.forward => '↑',
        MoveDir.back => '↓',
        MoveDir.left => '←',
        MoveDir.right => '→',
        MoveDir.none => '•',
      };

  String get label => switch (this) {
        MoveDir.forward => 'FORWARD',
        MoveDir.back => 'BACK',
        MoveDir.left => 'LEFT',
        MoveDir.right => 'RIGHT',
        MoveDir.none => '—',
      };

  bool get isVertical => this == MoveDir.forward || this == MoveDir.back;

  bool sameAxisAs(MoveDir other) => isVertical == other.isVertical;
}

/// Result of processing a single frame.
class MotionResult {
  const MotionResult({
    required this.box,
    required this.center,
    required this.velocity,
    required this.matchCount,
    required this.hasObject,
  });

  final Rect? box; // display-space bounding box
  final Offset? center; // display-space centroid
  final Offset velocity; // smoothed motion, display space, y-down
  final int matchCount;
  final bool hasObject;

  static const empty = MotionResult(
    box: null,
    center: null,
    velocity: Offset.zero,
    matchCount: 0,
    hasObject: false,
  );

  double get speed => velocity.distance;

  MoveDir get dominantDir {
    if (speed < 0.004) return MoveDir.none;
    if (velocity.dx.abs() >= velocity.dy.abs()) {
      return velocity.dx > 0 ? MoveDir.right : MoveDir.left;
    }
    return velocity.dy < 0 ? MoveDir.forward : MoveDir.back;
  }
}

class FrameMotionTracker {
  FrameMotionTracker({this.cols = 54, this.rows = 40});

  final int cols;
  final int rows;

  // Target marker hue (0–360) + acceptance thresholds (set by setTarget).
  double _refHue = 0;
  double _satMin = 0.4;
  double _valMin = 0.2;
  double _hueTol = 20;
  bool _armed = false;
  bool _acquiring = true;

  Offset _lastCenterImg = const Offset(0.5, 0.5);
  Offset _velEma = Offset.zero;
  Offset? _prevDispCenter;
  Rect? _smoothBox;
  int _missFrames = 0;

  // Motion (hand-movement) fusion: previous coarse luma grid.
  List<double>? _prevLuma;

  static const double _win = 0.15; // mean-shift window radius
  static const int _minCells = 3;

  // When true, display coordinates are rotated 90° — used when the phone is
  // held sideways but the UI stays portrait (up/down ↔ left/right swap).
  bool _rot90 = false;
  void setDisplayRotated(bool v) => _rot90 = v;

  bool get isArmed => _armed;

  /// Arm the tracker for a marker of the given [hue] (0–360). Warm hues
  /// (red/orange) sit close to wood + skin, so they are gated tighter.
  void setTarget(double hue) {
    _refHue = hue % 360;
    final warm = _refHue < 45 || _refHue > 330;
    _hueTol = warm ? 14 : 26;
    _satMin = warm ? 0.5 : 0.34;
    _valMin = 0.2;
    _armed = true;
    _acquiring = true;
    _lastCenterImg = const Offset(0.5, 0.5);
    _velEma = Offset.zero;
    _prevDispCenter = null;
    _smoothBox = null;
    _missFrames = 0;
    _prevLuma = null;
  }

  void reset() {
    _armed = false;
    _acquiring = true;
  }

  MotionResult process(CameraImage image) {
    if (!_armed) return MotionResult.empty;
    final motion = _computeMotion(image);

    // Acquire: no lock yet → scan the whole frame for the marker blob.
    if (_acquiring) {
      final seed = _autoAcquire(image);
      if (seed == null) {
        return MotionResult.empty; // still searching
      }
      _lastCenterImg = seed;
      _acquiring = false;
    }

    final win = _win * (1 + _missFrames * 0.3);
    var est = _lastCenterImg;
    var g = _gather(image, est, win);
    for (var it = 0; it < 3 && g.count >= _minCells; it++) {
      final moved = (g.centroid - est).distance;
      est = g.centroid;
      if (moved < 0.008) break;
      g = _gather(image, est, win);
    }

    // Colour + motion fusion: weak lock but the hand/prop is moving → re-seed
    // at the motion centroid and retry.
    if (g.count < 6 && motion.$1 != null && motion.$2 > 0.015) {
      final gm = _gather(image, motion.$1!, _win * 1.6);
      if (gm.count > g.count) {
        est = gm.centroid;
        g = gm;
      }
    }

    if (g.count < _minCells) {
      _missFrames = math.min(_missFrames + 1, 30);
      _velEma = _velEma * 0.5;
      // Fully lost for a while → go back to whole-frame acquisition.
      if (_missFrames > 10) _acquiring = true;
      final keep = _missFrames < 12 ? _smoothBox : (_smoothBox = null);
      return MotionResult(
        box: keep,
        center: keep?.center,
        velocity: _velEma,
        matchCount: g.count,
        hasObject: keep != null,
      );
    }
    _missFrames = 0;
    est = g.centroid;
    final k = g.count >= 10 ? 0.7 : 0.4;
    _lastCenterImg = Offset.lerp(_lastCenterImg, est, k)!;

    final dispCenter = _toDisplayPoint(est);
    final dispBox = _toDisplayRect(g.box);
    if (_prevDispCenter != null) {
      _velEma = _velEma * 0.6 + (dispCenter - _prevDispCenter!) * 0.4;
    }
    _prevDispCenter = dispCenter;
    _smoothBox =
        _smoothBox == null ? dispBox : Rect.lerp(_smoothBox!, dispBox, 0.5)!;

    return MotionResult(
      box: _smoothBox,
      center: dispCenter,
      velocity: _velEma,
      matchCount: g.count,
      hasObject: true,
    );
  }

  /// Whole-frame search for the densest cluster of target-hue cells. Returns an
  /// image-space seed, or null if no convincing blob is present.
  Offset? _autoAcquire(CameraImage image) {
    final mxs = <double>[], mys = <double>[];
    for (var r = 0; r < rows; r++) {
      final ny = (r + 0.5) / rows;
      for (var c = 0; c < cols; c++) {
        final nx = (c + 0.5) / cols;
        final (pr, pg, pb) = _sampleRgb(image, nx, ny);
        final (hue, sat, val) = _rgb2hsv(pr, pg, pb);
        if (sat < _satMin || val < _valMin) continue;
        if (_hueDiff(hue, _refHue) > _hueTol) continue;
        mxs.add(nx);
        mys.add(ny);
      }
    }
    final n = mxs.length;
    if (n < 5) return null;

    const rad2 = 0.1 * 0.1;
    var bestI = 0, bestCount = 0;
    for (var i = 0; i < n; i++) {
      var cnt = 0;
      for (var j = 0; j < n; j++) {
        final dx = mxs[i] - mxs[j], dy = mys[i] - mys[j];
        if (dx * dx + dy * dy <= rad2) cnt++;
      }
      if (cnt > bestCount) {
        bestCount = cnt;
        bestI = i;
      }
    }
    if (bestCount < 4) return null;

    var sx = 0.0, sy = 0.0, k = 0;
    for (var j = 0; j < n; j++) {
      final dx = mxs[bestI] - mxs[j], dy = mys[bestI] - mys[j];
      if (dx * dx + dy * dy <= rad2) {
        sx += mxs[j];
        sy += mys[j];
        k++;
      }
    }
    return Offset(sx / k, sy / k);
  }

  /// Accumulate hue-matching cells within [win] of [est] (image-normalised).
  ({int count, Offset centroid, Rect box}) _gather(
    CameraImage image,
    Offset est,
    double win,
  ) {
    final win2 = win * win;

    var sumX = 0.0, sumY = 0.0, count = 0;
    var minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    for (var r = 0; r < rows; r++) {
      final ny = (r + 0.5) / rows;
      final dy = ny - est.dy;
      if (dy * dy > win2) continue;
      for (var c = 0; c < cols; c++) {
        final nx = (c + 0.5) / cols;
        final dx = nx - est.dx;
        if (dx * dx + dy * dy > win2) continue;
        final (pr, pg, pb) = _sampleRgb(image, nx, ny);
        final (hue, sat, val) = _rgb2hsv(pr, pg, pb);
        if (sat < _satMin || val < _valMin) continue;
        if (_hueDiff(hue, _refHue) > _hueTol) continue;
        sumX += nx;
        sumY += ny;
        count++;
        if (nx < minX) minX = nx;
        if (nx > maxX) maxX = nx;
        if (ny < minY) minY = ny;
        if (ny > maxY) maxY = ny;
      }
    }
    if (count == 0) return (count: 0, centroid: est, box: Rect.zero);
    return (
      count: count,
      centroid: Offset(sumX / count, sumY / count),
      box: Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  /// Coarse frame-differencing: image-space centroid of motion + 0–1 energy.
  (Offset?, double) _computeMotion(CameraImage image) {
    final grid = List<double>.filled(cols * rows, 0);
    for (var r = 0; r < rows; r++) {
      final ny = (r + 0.5) / rows;
      for (var c = 0; c < cols; c++) {
        final nx = (c + 0.5) / cols;
        final (pr, pg, pb) = _sampleRgb(image, nx, ny);
        grid[r * cols + c] = 0.299 * pr + 0.587 * pg + 0.114 * pb;
      }
    }
    final prev = _prevLuma;
    _prevLuma = grid;
    if (prev == null) return (null, 0);

    var sx = 0.0, sy = 0.0, wsum = 0.0, active = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        final d = (grid[i] - prev[i]).abs();
        if (d < 16) continue;
        sx += (c + 0.5) / cols * d;
        sy += (r + 0.5) / rows * d;
        wsum += d;
        active++;
      }
    }
    final energy = active / (cols * rows);
    if (wsum <= 0 || active < 6) return (null, energy);
    return (Offset(sx / wsum, sy / wsum), energy);
  }

  // ---- HSV helpers ----

  (double, double, double) _rgb2hsv(double r, double g, double b) {
    final rr = r / 255, gg = g / 255, bb = b / 255;
    final mx = math.max(rr, math.max(gg, bb));
    final mn = math.min(rr, math.min(gg, bb));
    final d = mx - mn;
    double hue;
    if (d == 0) {
      hue = 0;
    } else if (mx == rr) {
      hue = 60 * ((((gg - bb) / d) % 6));
    } else if (mx == gg) {
      hue = 60 * (((bb - rr) / d) + 2);
    } else {
      hue = 60 * (((rr - gg) / d) + 4);
    }
    if (hue < 0) hue += 360;
    final sat = mx == 0 ? 0.0 : d / mx;
    return (hue, sat, mx);
  }

  double _hueDiff(double a, double b) {
    var d = (a - b).abs() % 360;
    if (d > 180) d = 360 - d;
    return d;
  }

  // ---- coordinate transforms (image buffer ↔ display; identity here) ----

  Offset _toDisplayPoint(Offset img) =>
      _rot90 ? Offset(img.dy, 1.0 - img.dx) : img;

  Rect _toDisplayRect(Rect img) {
    if (!_rot90) return img;
    final a = _toDisplayPoint(img.topLeft);
    final b = _toDisplayPoint(img.bottomRight);
    return Rect.fromLTRB(
      math.min(a.dx, b.dx),
      math.min(a.dy, b.dy),
      math.max(a.dx, b.dx),
      math.max(a.dy, b.dy),
    );
  }

  // ---- pixel access ----

  /// Sample an RGB pixel at normalised (nx, ny). Handles both iOS BGRA8888 and
  /// Android YUV_420_888 (luma Y + subsampled chroma U/V planes) — the latter is
  /// what the Android camera actually delivers even when bgra8888 is requested,
  /// so colour tracking now works on Android instead of seeing grayscale.
  (double, double, double) _sampleRgb(CameraImage image, double nx, double ny) {
    final w = image.width, h = image.height;
    final ix = (nx * w).floor().clamp(0, w - 1);
    final iy = (ny * h).floor().clamp(0, h - 1);
    final group = image.format.group;

    if (group == ImageFormatGroup.bgra8888) {
      final p = image.planes.first;
      final idx = iy * p.bytesPerRow + ix * 4;
      if (idx + 2 >= p.bytes.length) return (0, 0, 0);
      return (p.bytes[idx + 2].toDouble(), p.bytes[idx + 1].toDouble(), p.bytes[idx].toDouble());
    }

    if (group == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
      final yP = image.planes[0], uP = image.planes[1], vP = image.planes[2];
      final uvStride = uP.bytesPerPixel ?? 1; // 2 for semi-planar (NV21), 1 for planar
      final yIdx = iy * yP.bytesPerRow + ix;
      final uIdx = (iy >> 1) * uP.bytesPerRow + (ix >> 1) * uvStride;
      final vIdx = (iy >> 1) * vP.bytesPerRow + (ix >> 1) * uvStride;
      if (yIdx >= yP.bytes.length || uIdx >= uP.bytes.length || vIdx >= vP.bytes.length) {
        return (0, 0, 0);
      }
      final yv = yP.bytes[yIdx].toDouble();
      final u = uP.bytes[uIdx].toDouble() - 128.0;
      final v = vP.bytes[vIdx].toDouble() - 128.0;
      final r = (yv + 1.370705 * v).clamp(0.0, 255.0);
      final g = (yv - 0.337633 * u - 0.698001 * v).clamp(0.0, 255.0);
      final b = (yv + 1.732446 * u).clamp(0.0, 255.0);
      return (r, g, b);
    }

    // Fallback: single-plane grayscale.
    final p = image.planes.first;
    final idx = iy * p.bytesPerRow + ix;
    final val = idx < p.bytes.length ? p.bytes[idx].toDouble() : 0.0;
    return (val, val, val);
  }
}
