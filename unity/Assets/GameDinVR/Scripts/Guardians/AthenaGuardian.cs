using UnityEngine;

/// <summary>
/// Represents Athena, the strategist guardian.
/// Replies with a simple status when addressed with the word "status".
/// </summary>
public class AthenaGuardian : GuardianBase {
    void Start(){ GuardianName = "Athena"; Role = "Strategy & Intelligence"; }

    public override void OnMessage(string from, string message){
        if (message.Contains("status")){
            Whisper("Lilybear", "Athena: All systems nominal.");
        }
    }
}
