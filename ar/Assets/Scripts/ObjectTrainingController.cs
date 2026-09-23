using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;

/// <summary>
/// Drives the everyday-object training lessons (mouse → steering,
/// water bottle → throttle, book → bucket). Uses AR Foundation object
/// tracking to detect the physical prop, visualises it, evaluates the
/// trainee's motion for each lesson step, and reports progress to Flutter
/// through <see cref="ArBridge"/>.
///
/// Implements FR-LEARN. Owner: P3.
/// </summary>
[RequireComponent(typeof(ARTrackedObjectManager))]
public class ObjectTrainingController : MonoBehaviour
{
    [Tooltip("How many steps a lesson has (mirrors DefaultModules in Flutter).")]
    public int stepsPerLesson = 5;

    [Tooltip("Prefab drawn on a detected object (bounding box + instruction).")]
    public GameObject trackedObjectVisualPrefab;

    private ARTrackedObjectManager _trackedObjectManager;
    private readonly HashSet<string> _wantedObjects = new HashSet<string>();
    private readonly Dictionary<string, Vector3> _lastPose = new Dictionary<string, Vector3>();

    private string _activeLesson;
    private int _activeStep;
    private bool _stepRunning;

    private void Awake()
    {
        _trackedObjectManager = GetComponent<ARTrackedObjectManager>();
    }

    private void OnEnable()
    {
        _trackedObjectManager.trackedObjectsChanged += OnTrackedObjectsChanged;
    }

    private void OnDisable()
    {
        _trackedObjectManager.trackedObjectsChanged -= OnTrackedObjectsChanged;
    }

    // ------------------------------------------------------------------ //
    // Commands from Flutter (via ArBridge)
    // ------------------------------------------------------------------ //

    /// <summary>Configure which real-world objects AR should look for.</summary>
    public void SetTrackedObjects(string[] objectIds)
    {
        _wantedObjects.Clear();
        if (objectIds != null)
        {
            foreach (var id in objectIds) _wantedObjects.Add(id);
        }
        Debug.Log("[Training] Now tracking: " + string.Join(", ", _wantedObjects));
    }

    /// <summary>Begin (or resume) a lesson at the given step.</summary>
    public void StartLesson(string lessonId, int step)
    {
        _activeLesson = lessonId;
        _activeStep = step;
        StopAllCoroutines();
        StartCoroutine(RunStep());
    }

    // ------------------------------------------------------------------ //
    // Object tracking
    // ------------------------------------------------------------------ //

    private void OnTrackedObjectsChanged(ARTrackedObjectsChangedEventArgs args)
    {
        foreach (var t in args.added)
        {
            AttachVisual(t);
            ReportTracking(NameOf(t), true);
        }
        foreach (var t in args.updated)
        {
            _lastPose[NameOf(t)] = t.transform.position;
        }
        foreach (var t in args.removed)
        {
            ReportTracking(NameOf(t), false);
        }
    }

    private static string NameOf(ARTrackedObject t) =>
        t.referenceObject != null ? t.referenceObject.name : t.trackableId.ToString();

    private void AttachVisual(ARTrackedObject t)
    {
        if (trackedObjectVisualPrefab == null) return;
        Instantiate(trackedObjectVisualPrefab, t.transform);
    }

    private void ReportTracking(string objectId, bool tracked)
    {
        if (ArBridge.Instance != null) ArBridge.Instance.SendTrackingStatus(objectId, tracked);
    }

    // ------------------------------------------------------------------ //
    // Lesson evaluation
    // ------------------------------------------------------------------ //

    /// <summary>
    /// Runs one lesson step: watches the tracked prop's motion for the
    /// expected gesture, scores it, and reports completion to Flutter.
    /// The motion analysis here is a lightweight demo; replace with the real
    /// per-step gesture classifier as props/scenes are authored.
    /// </summary>
    private IEnumerator RunStep()
    {
        _stepRunning = true;
        var elapsed = 0f;
        var motionAccum = 0f;
        Vector3? prev = null;

        // Sample the tracked object's movement for a short window.
        while (elapsed < 2.5f)
        {
            var pose = CurrentTrackedPose();
            if (pose.HasValue && prev.HasValue)
                motionAccum += Vector3.Distance(pose.Value, prev.Value);
            prev = pose;
            elapsed += Time.deltaTime;
            yield return null;
        }

        // Score: more deliberate motion → higher score, clamped to a friendly
        // demo range so the trainee always makes visible progress.
        var score = Mathf.Clamp(70f + motionAccum * 500f, 60f, 100f);
        _stepRunning = false;

        if (ArBridge.Instance != null)
        {
            ArBridge.Instance.SendLessonStepComplete(_activeLesson, _activeStep, score, stepsPerLesson);
        }
    }

    private Vector3? CurrentTrackedPose()
    {
        foreach (var kv in _lastPose) return kv.Value; // first tracked prop
        return null;
    }

    public bool IsStepRunning => _stepRunning;
}
