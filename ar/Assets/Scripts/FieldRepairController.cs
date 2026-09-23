using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// AR field-repair: loads a machine model, renders an exploded view, and
/// highlights the fault-flagged component. Reports load + selection back to
/// Flutter via <see cref="ArBridge"/>.
///
/// Implements FR-REPAIR. Owner: P3.
///
/// Model assets are expected under <c>Resources/Models/&lt;modelId&gt;</c>
/// (glTF/prefab). Each faultable part should be a child GameObject whose name
/// matches the <c>partId</c> used by Flutter, tagged so it can be highlighted.
/// </summary>
public class FieldRepairController : MonoBehaviour
{
    [Tooltip("Root transform the loaded machine model is parented under.")]
    public Transform modelRoot;

    [Tooltip("Material applied to a faulted / highlighted part.")]
    public Material highlightMaterial;

    [Tooltip("How far parts move apart in the exploded view.")]
    public float explodeDistance = 0.15f;

    private GameObject _model;
    private readonly Dictionary<string, Renderer> _parts = new Dictionary<string, Renderer>();
    private readonly Dictionary<Renderer, Material> _originalMaterials = new Dictionary<Renderer, Material>();
    private string _highlightedPartId;

    // ------------------------------------------------------------------ //
    // Commands from Flutter (via ArBridge)
    // ------------------------------------------------------------------ //

    /// <summary>Instantiate a machine model by id.</summary>
    public void LoadModel(string modelId, string faultCode)
    {
        StartCoroutine(LoadModelRoutine(modelId, faultCode));
    }

    private IEnumerator LoadModelRoutine(string modelId, string faultCode)
    {
        if (_model != null) Destroy(_model);
        _parts.Clear();
        _originalMaterials.Clear();

        var prefab = Resources.Load<GameObject>("Models/" + modelId);
        bool ok = prefab != null;
        if (ok)
        {
            _model = Instantiate(prefab, modelRoot != null ? modelRoot : transform);
            IndexParts(_model);
        }
        else
        {
            Debug.LogWarning("[Repair] Model not found in Resources/Models/: " + modelId);
        }

        // Let one frame pass so the instantiated hierarchy is ready.
        yield return null;

        if (ArBridge.Instance != null) ArBridge.Instance.SendModelLoaded(modelId, ok);

        if (ok && !string.IsNullOrEmpty(faultCode))
        {
            // If a fault code came with the load, pre-highlight nothing until
            // Flutter picks a part — Flutter drives part selection explicitly.
        }
    }

    private void IndexParts(GameObject root)
    {
        foreach (var r in root.GetComponentsInChildren<Renderer>())
        {
            _parts[r.gameObject.name] = r;
            _originalMaterials[r] = r.sharedMaterial;
        }
    }

    /// <summary>Highlight a specific faulted part and notify Flutter.</summary>
    public void HighlightPart(string partId, string faultCode)
    {
        ClearHighlight();

        if (_parts.TryGetValue(partId, out var rend) && highlightMaterial != null)
        {
            rend.material = highlightMaterial;
            _highlightedPartId = partId;
        }

        if (ArBridge.Instance != null)
        {
            ArBridge.Instance.SendPartSelected(partId, Prettify(partId));
        }
    }

    private void ClearHighlight()
    {
        if (_highlightedPartId != null &&
            _parts.TryGetValue(_highlightedPartId, out var rend) &&
            _originalMaterials.TryGetValue(rend, out var mat))
        {
            rend.material = mat;
        }
        _highlightedPartId = null;
    }

    // ------------------------------------------------------------------ //
    // Exploded view
    // ------------------------------------------------------------------ //

    /// <summary>Push each part outward from the model centre (or restore).</summary>
    public void SetExploded(bool exploded)
    {
        if (_model == null) return;
        var center = _model.transform.position;
        foreach (var rend in _parts.Values)
        {
            var dir = (rend.transform.position - center).normalized;
            var target = exploded
                ? rend.transform.position + dir * explodeDistance
                : center;
            StartCoroutine(MoveTo(rend.transform, target));
        }
    }

    private IEnumerator MoveTo(Transform t, Vector3 target)
    {
        var start = t.position;
        var elapsed = 0f;
        while (elapsed < 0.4f)
        {
            t.position = Vector3.Lerp(start, target, elapsed / 0.4f);
            elapsed += Time.deltaTime;
            yield return null;
        }
        t.position = target;
    }

    private static string Prettify(string id) =>
        string.IsNullOrEmpty(id) ? id : id.Replace('_', ' ');
}
