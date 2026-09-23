using UnityEngine;
using TMPro;

/// <summary>
/// Visual drawn on a detected training prop (mouse / bottle / book): a green
/// bounding box plus floating, camera-facing instruction text. Attach this to
/// the <c>trackedObjectVisualPrefab</c> referenced by
/// <see cref="ObjectTrainingController"/> — it is instantiated as a child of
/// each <c>ARTrackedObject</c>, so tracking + Flutter reporting live in the
/// controller and this class stays purely presentational.
/// </summary>
public class MouseTracker : MonoBehaviour
{
    [Tooltip("Instruction shown above the tracked object.")]
    public string instructionText = "Move the object as instructed";

    [Tooltip("Half-extent of the bounding box, in metres.")]
    public float extent = 0.05f;

    private void Start()
    {
        DrawBoundingBox();
        DrawInstruction();
    }

    private void DrawBoundingBox()
    {
        var boxObj = new GameObject("BoundingBox");
        boxObj.transform.SetParent(transform, false);

        var line = boxObj.AddComponent<LineRenderer>();
        line.useWorldSpace = false;
        line.startWidth = 0.005f;
        line.endWidth = 0.005f;
        line.material = new Material(Shader.Find("Sprites/Default"));
        line.startColor = Color.green;
        line.endColor = Color.green;
        line.positionCount = 5;
        line.SetPositions(new Vector3[]
        {
            new Vector3(-extent, 0, -extent),
            new Vector3(extent, 0, -extent),
            new Vector3(extent, 0, extent),
            new Vector3(-extent, 0, extent),
            new Vector3(-extent, 0, -extent) // close the loop
        });
    }

    private void DrawInstruction()
    {
        var textObj = new GameObject("InstructionText");
        textObj.transform.SetParent(transform, false);
        textObj.transform.localPosition = new Vector3(0, 0.08f, 0);

        var textMesh = textObj.AddComponent<TextMeshPro>();
        textMesh.text = instructionText;
        textMesh.fontSize = 2;
        textMesh.alignment = TextAlignmentOptions.Center;
        textMesh.color = Color.yellow;

        textObj.AddComponent<Billboard>();
    }
}

/// <summary>Makes 3D text/objects always face the main camera (billboarding).</summary>
public class Billboard : MonoBehaviour
{
    private Camera _mainCamera;

    private void Start() => _mainCamera = Camera.main;

    private void LateUpdate()
    {
        if (_mainCamera == null) return;
        transform.LookAt(
            transform.position + _mainCamera.transform.rotation * Vector3.forward,
            _mainCamera.transform.rotation * Vector3.up);
    }
}
