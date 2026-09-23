using System;
using UnityEngine;

/// <summary>
/// Central Unity↔Flutter message hub. Parses commands sent from Flutter via
/// <c>UnityWidgetController.postMessage("ArBridge", "ReceiveMessage", json)</c>
/// and dispatches them to the AR controllers. Emits typed JSON events back to
/// Flutter that match <c>app/lib/services/ar_bridge/ar_message.dart</c>.
///
/// Contract: P3 ↔ P4 (AGENTS.md interface contract #4). See ar/PROTOCOL.md.
/// </summary>
public class ArBridge : MonoBehaviour
{
    public static ArBridge Instance { get; private set; }

    [Tooltip("Handles everyday-object training lessons (mouse→steering, etc.).")]
    public ObjectTrainingController training;

    [Tooltip("Handles AR field-repair (load model, highlight faulted part).")]
    public FieldRepairController repair;

    // ------------------------------------------------------------------ //
    // Inbound command envelope. JsonUtility fills the fields that are
    // present for a given command 'type' and ignores the rest.
    // ------------------------------------------------------------------ //
    [Serializable]
    private class InboundMessage
    {
        public string type;
        public string modelId;
        public string faultCode;
        public string partId;
        public string lessonId;
        public int step;
        public string[] objectIds;
    }

    private void Awake()
    {
        Instance = this;
    }

    private void Start()
    {
        // Tell Flutter the AR engine has booted and is ready for commands.
        SendReady();
    }

    /// <summary>
    /// Entry point invoked by Flutter. Must keep this exact name + signature.
    /// </summary>
    public void ReceiveMessage(string message)
    {
        Debug.Log("[ArBridge] ← Flutter: " + message);
        InboundMessage msg;
        try
        {
            msg = JsonUtility.FromJson<InboundMessage>(message);
        }
        catch (Exception e)
        {
            Debug.LogError("[ArBridge] Bad message: " + e.Message);
            return;
        }
        if (msg == null || string.IsNullOrEmpty(msg.type)) return;

        switch (msg.type)
        {
            case "loadModel":
                if (repair != null) repair.LoadModel(msg.modelId, msg.faultCode);
                break;
            case "highlightPart":
                if (repair != null) repair.HighlightPart(msg.partId, msg.faultCode);
                break;
            case "startLesson":
                if (training != null) training.StartLesson(msg.lessonId, msg.step);
                break;
            case "setTrackedObjects":
                if (training != null) training.SetTrackedObjects(msg.objectIds);
                break;
            default:
                Debug.LogWarning("[ArBridge] Unknown command: " + msg.type);
                break;
        }
    }

    // ------------------------------------------------------------------ //
    // Outbound events (typed → correct JSON incl. the "type" discriminator).
    // ------------------------------------------------------------------ //

    [Serializable] private class ReadyEvent { public string type = "ready"; public bool success = true; }
    [Serializable] private class ModelLoadedEvent { public string type = "onModelLoaded"; public string modelId; public bool success; }
    [Serializable] private class PartSelectedEvent { public string type = "onPartSelected"; public string partId; public string partName; }
    [Serializable] private class LessonStepEvent { public string type = "onLessonStepComplete"; public string lessonId; public int step; public float score; public int totalSteps; }
    [Serializable] private class TrackingEvent { public string type = "onTrackingStatus"; public string objectId; public bool tracked; }

    public void SendReady() => Send(JsonUtility.ToJson(new ReadyEvent()));

    public void SendModelLoaded(string modelId, bool success) =>
        Send(JsonUtility.ToJson(new ModelLoadedEvent { modelId = modelId, success = success }));

    public void SendPartSelected(string partId, string partName) =>
        Send(JsonUtility.ToJson(new PartSelectedEvent { partId = partId, partName = partName }));

    public void SendLessonStepComplete(string lessonId, int step, float score, int totalSteps) =>
        Send(JsonUtility.ToJson(new LessonStepEvent
        {
            lessonId = lessonId, step = step, score = score, totalSteps = totalSteps
        }));

    public void SendTrackingStatus(string objectId, bool tracked) =>
        Send(JsonUtility.ToJson(new TrackingEvent { objectId = objectId, tracked = tracked }));

    private void Send(string json)
    {
        Debug.Log("[ArBridge] → Flutter: " + json);
#if UNITY_ANDROID || UNITY_IOS
        // Provided by flutter_unity_widget's UnityMessageManager. Guarded so
        // the project still compiles/plays in the Editor without the plugin.
        try
        {
            UnityMessageManager.Instance.SendMessageToFlutter(json);
        }
        catch (Exception e)
        {
            Debug.LogWarning("[ArBridge] UnityMessageManager unavailable: " + e.Message);
        }
#endif
    }
}
