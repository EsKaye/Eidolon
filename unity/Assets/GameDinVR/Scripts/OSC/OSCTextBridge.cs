using UnityEngine;

/// <summary>
/// Placeholder script for future OSC bridge; exposes a method to set text
/// from external calls.
/// </summary>
public class OSCTextBridge : MonoBehaviour {
    public TextMesh Target;
    public void SetText(string s){ if (Target) Target.text = s; }
}
