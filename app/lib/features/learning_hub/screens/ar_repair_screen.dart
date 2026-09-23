/// AR Field Repair Screen — exploded-parts view + fault-highlighted component.
///
/// Per DESIGN.md §4.2: camera identifies machine, loads glTF model,
/// highlights faulted component, shows animated repair steps.
/// Uses AR bridge (mock mode) + ML client (RAG for repair guidance).
library;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../services/ar_bridge/ar_message.dart';
import '../../../services/ar_bridge/ar_providers.dart';
import '../../../services/ml_client/ml_models.dart';
import '../../../services/ml_client/ml_providers.dart';

class ArRepairScreen extends ConsumerStatefulWidget {
  const ArRepairScreen({super.key});

  @override
  ConsumerState<ArRepairScreen> createState() => _ArRepairScreenState();
}

class _ArRepairScreenState extends ConsumerState<ArRepairScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedPartId;
  String? _selectedPartName;
  bool _modelLoaded = false;
  bool _isExploded = false;
  String? _ragAnswer;
  bool _ragLoading = false;

  CameraController? _cameraController;
  late AnimationController _rotateController;

  // Simulated machine parts for the demo.
  static const _mockParts = [
    (id: 'engine_block', name: 'Engine Block', faultCode: 'E101'),
    (id: 'hydraulic_pump', name: 'Hydraulic Pump', faultCode: 'H203'),
    (id: 'turbocharger', name: 'Turbocharger', faultCode: 'E305'),
    (id: 'fuel_injector', name: 'Fuel Injector', faultCode: 'F102'),
    (id: 'coolant_system', name: 'Coolant System', faultCode: 'C201'),
  ];

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Load model on init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadModel();
      _initCamera();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    final bridge = ref.read(arBridgeProvider);
    await bridge.send(const LoadModelCommand(modelId: 'cat_excavator_320'));

    // Listen for load event.
    bridge.events.listen((event) {
      if (!mounted) return;
      if (event is ModelLoadedEvent && event.success) {
        setState(() => _modelLoaded = true);
      }
      if (event is PartSelectedEvent) {
        setState(() {
          _selectedPartId = event.partId;
          _selectedPartName = event.partName;
        });
      }
    });
  }

  Future<void> _selectPart(String partId, String faultCode) async {
    final bridge = ref.read(arBridgeProvider);
    await bridge.send(HighlightPartCommand(
      partId: partId,
      faultCode: faultCode,
    ));
    setState(() => _selectedPartId = partId);

    // Ask RAG for repair guidance.
    _queryRepairGuidance(faultCode);
  }

  Future<void> _queryRepairGuidance(String faultCode) async {
    setState(() {
      _ragLoading = true;
      _ragAnswer = null;
    });

    final client = ref.read(mlClientProvider);
    final response = await client.queryRag(RagQueryRequest(
      question: 'How to repair fault code $faultCode?',
      machineModel: 'CAT 320 Excavator',
      faultCode: faultCode,
    ));

    if (mounted) {
      setState(() {
        _ragAnswer = response.answer;
        _ragLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('AR Field Repair'),
        actions: [
          // Explode toggle
          IconButton(
            icon: Icon(
              _isExploded
                  ? Icons.compress_rounded
                  : Icons.open_with_rounded,
            ),
            tooltip: _isExploded ? 'Collapse View' : 'Exploded View',
            onPressed: () => setState(() => _isExploded = !_isExploded),
          ),
        ],
      ),
      body: Column(
        children: [
          // AR viewport (mock)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedPartId != null
                      ? CatColors.danger.withValues(alpha: 0.6)
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_cameraController != null && _cameraController!.value.isInitialized)
                    Positioned.fill(
                      child: CameraPreview(_cameraController!),
                    )
                  else
                    // 3D model placeholder when camera not ready
                    AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotateController.value * 2 * 3.14159,
                          child: Icon(
                            Icons.view_in_ar_rounded,
                            size: 100,
                            color: _selectedPartId != null
                                ? CatColors.danger.withValues(alpha: 0.4)
                                : theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        );
                      },
                    ),

                  // Status overlay
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_modelLoaded ? CatColors.success : CatColors.warning)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _modelLoaded
                                ? Icons.check_circle
                                : Icons.hourglass_top,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _modelLoaded ? 'Model Loaded' : 'Loading...',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Exploded view label
                  if (_isExploded)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'EXPLODED VIEW',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                  // Mock mode label removed
                ],
              ),
            ),
          ),

          // Parts panel + repair info
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: CatColors.textMuted,
                      tabs: const [
                        Tab(text: 'Components'),
                        Tab(text: 'Repair Guide'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPartsTab(theme),
                          _buildRepairTab(theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartsTab(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _mockParts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final part = _mockParts[index];
        final isSelected = _selectedPartId == part.id;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? CatColors.danger.withValues(alpha: 0.12)
                : theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? CatColors.danger.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? CatColors.danger.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: isSelected
                    ? CatColors.danger
                    : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              part.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            subtitle: Text(
              'Fault: ${part.faultCode}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? CatColors.danger : CatColors.textMuted,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.visibility, color: CatColors.danger, size: 20)
                : null,
            onTap: () => _selectPart(part.id, part.faultCode),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  Widget _buildRepairTab(ThemeData theme) {
    if (_selectedPartId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded,
                size: 48, color: CatColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'Select a component to see repair guidance',
              style: TextStyle(color: CatColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final partName =
        _mockParts.where((p) => p.id == _selectedPartId).firstOrNull?.name ??
            _selectedPartName ??
            _selectedPartId!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part header
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: CatColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                partName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // RAG answer
          if (_ragLoading)
            const Center(child: CircularProgressIndicator())
          else if (_ragAnswer != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'AI Repair Guidance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _ragAnswer!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: CatColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Mock repair steps
          const Text(
            'Repair Steps',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._buildMockRepairSteps(theme),
        ],
      ),
    );
  }

  List<Widget> _buildMockRepairSteps(ThemeData theme) {
    const steps = [
      'Isolate power and hydraulic lines',
      'Remove protective cover (4x M12 bolts)',
      'Disconnect electrical connectors',
      'Remove mounting bolts (torque: 85 Nm)',
      'Extract and replace component',
      'Reassemble in reverse order',
    ];

    return [
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[i],
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
