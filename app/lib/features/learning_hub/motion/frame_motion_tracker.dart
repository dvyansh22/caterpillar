/// Real-time, on-device motion tracker for the AR training lessons.
///
/// Consumes raw camera frames, finds the region that is *moving* (the prop the
/// trainee is holding — e.g. a mouse), and returns a smoothed bounding box plus
/// a motion vector, both expressed in **display** coordinates so the overlay
/// lines up with what the user sees. No ML model, no network — just frame
/// differencing over a coarse luminance grid, which is cheap enough to run
/// every frame on the phone.
///
/// Owner: P3 (AGENTS.md — everyday-object training, FR-LEARN).
library;

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
    required this.velocity,
    required this.energy,
    required this.hasObject,
  });

  /// Bounding box around the moving object, normalised (0–1) in display space.
  final Rect? box;

  /// Smoothed motion vector, normalised display space, y-down.
  final Offset velocity;

  /// Fraction of the frame that is moving (0–1) — motion strength.
  final double energy;

  /// Whether a trackable object is currently visible.
  final bool hasObject;

  static const empty = MotionResult(
    box: null,
    velocity: Offset.zero,
    energy: 0,
    hasObject: false,
  );

  double get speed => velocity.distance;

  /// The dominant on-screen movement direction, or [MoveDir.none] if still.
  MoveDir get dominantDir {
    if (speed < 0.004) return MoveDir.none;
    if (velocity.dx.abs() >= velocity.dy.abs()) {
      return velocity.dx > 0 ? MoveDir.right : MoveDir.left;
    }
    return velocity.dy < 0 ? MoveDir.forward : MoveDir.back;
  }
}

/// Tracks motion across frames using a coarse luminance grid.
class FrameMotionTracker {
  FrameMotionTracker({this.cols = 32, this.rows = 24, this.mirror = false});

  /// Grid resolution used for differencing (independent of camera resolution).
  final int cols;
  final int rows;

  /// True for the front camera (its preview is horizontally mirrored).
  final bool mirror;

  List<double>? _prev;
  Offset? _prevCentroid;
  Offset _velEma = Offset.zero;
  Rect? _smoothBox;
  int _idleFrames = 0;

  /// Motion threshold per cell (0–255 luma delta).
  static const double _cellThreshold = 16.0;

  /// Reset all temporal state (call when the lesson restarts).
  void reset() {
    _prev = null;
    _prevCentroid = null;
    _velEma = Offset.zero;
    _smoothBox = null;
    _idleFrames = 0;
  }

  MotionResult process(CameraImage image) {
    final grid = _sampleGrid(image);
    final prev = _prev;
    _prev = grid;
    if (prev == null) return MotionResult.empty;

    // --- Difference the current grid against the previous one. ---
    var active = 0;
    var sumX = 0.0, sumY = 0.0;
    var minC = cols, maxC = -1, minR = rows, maxR = -1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        if ((grid[i] - prev[i]).abs() < _cellThreshold) continue;
        active++;
        sumX += c;
        sumY += r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
      }
    }

    final energy = active / (cols * rows);

    // Not enough motion → hold the last box briefly so it doesn't flicker.
    if (active < 5) {
      _idleFrames++;
      _velEma = _velEma * 0.5;
      _prevCentroid = null;
      final keep = _idleFrames < 14 ? _smoothBox : (_smoothBox = null);
      return MotionResult(
        box: keep,
        velocity: _velEma,
        energy: energy,
        hasObject: keep != null,
      );
    }
    _idleFrames = 0;

    // Centroid + bounding box in image-normalised coords.
    final cx = (sumX / active) / cols;
    final cy = (sumY / active) / rows;
    final imgBox = Rect.fromLTRB(
      minC / cols,
      minR / rows,
      (maxC + 1) / cols,
      (maxR + 1) / rows,
    );

    // Transform image space → display space (portrait, sensor is landscape).
    final dispCentroid = _toDisplayPoint(Offset(cx, cy));
    final dispBox = _toDisplayRect(imgBox);

    // Velocity from centroid displacement, smoothed.
    if (_prevCentroid != null) {
      final inst = dispCentroid - _prevCentroid!;
      _velEma = _velEma * 0.6 + inst * 0.4;
    }
    _prevCentroid = dispCentroid;

    // Smooth the box for a stable overlay.
    _smoothBox = _smoothBox == null
        ? dispBox
        : Rect.lerp(_smoothBox!, dispBox, 0.5)!;

    return MotionResult(
      box: _smoothBox,
      velocity: _velEma,
      energy: energy,
      hasObject: true,
    );
  }

  // ---- coordinate transforms (90° CW rotation for portrait) ----

  Offset _toDisplayPoint(Offset img) {
    final dx = mirror ? img.dy : 1.0 - img.dy;
    final dy = img.dx;
    return Offset(dx, dy);
  }

  Rect _toDisplayRect(Rect img) {
    final a = _toDisplayPoint(img.topLeft);
    final b = _toDisplayPoint(img.bottomRight);
    return Rect.fromLTRB(
      a.dx < b.dx ? a.dx : b.dx,
      a.dy < b.dy ? a.dy : b.dy,
      a.dx > b.dx ? a.dx : b.dx,
      a.dy > b.dy ? a.dy : b.dy,
    );
  }

  // ---- luminance sampling ----

  List<double> _sampleGrid(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bpr = plane.bytesPerRow;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final bpp = isBgra ? 4 : 1;
    final w = image.width;
    final h = image.height;
    final grid = List<double>.filled(cols * rows, 0);

    for (var r = 0; r < rows; r++) {
      final iy = (((r + 0.5) / rows) * h).floor().clamp(0, h - 1);
      for (var c = 0; c < cols; c++) {
        final ix = (((c + 0.5) / cols) * w).floor().clamp(0, w - 1);
        final idx = iy * bpr + ix * bpp;
        double luma;
        if (isBgra) {
          if (idx + 2 >= bytes.length) {
            luma = 0;
          } else {
            luma = 0.114 * bytes[idx] +
                0.587 * bytes[idx + 1] +
                0.299 * bytes[idx + 2];
          }
        } else {
          luma = idx < bytes.length ? bytes[idx].toDouble() : 0;
        }
        grid[r * cols + c] = luma;
      }
    }
    return grid;
  }
}
