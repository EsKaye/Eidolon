using UnityEngine;

/// <summary>
/// Lilybear acts as voice and operations hub. For demo purposes it echoes
/// `/route <msg>` commands to all guardians.
/// </summary>
public class LilybearController : GuardianBase {
    [TextArea] public string LastMessage;

    void Start(){
        GuardianName = "Lilybear";
        Role = "Voice & Operations";
    }

    public override void OnMessage(string from, string message){
        LastMessage = $"{from}: {message}";
        if (message.StartsWith("/route ")){
            var payload = message.Substring(7);
            Whisper("*", payload);
        }
    }

    [ContextMenu("Test Whisper")]
    void TestWhisper(){
        Whisper("*", "The council is assembled.");
    }
}
