using UnityEngine;
using System;

/// <summary>
/// Simple in-scene event bus so guardians can whisper to each other.
/// </summary>
public class LilybearOpsBus : MonoBehaviour {
    public static LilybearOpsBus I;
    public delegate void Whisper(string from, string to, string message);
    public event Whisper OnWhisper;

    void Awake(){ I = this; }

    public void Say(string from, string to, string message){
        OnWhisper?.Invoke(from, to, message);
        Debug.Log($"[LilybearBus] {from} → {to}: {message}");
    }
}
