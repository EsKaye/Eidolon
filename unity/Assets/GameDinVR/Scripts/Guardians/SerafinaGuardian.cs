using UnityEngine;

/// <summary>
/// Serafina routes blessings to ShadowFlowers when asked.
/// </summary>
public class SerafinaGuardian : GuardianBase {
    void Start(){ GuardianName = "Serafina"; Role = "Comms & Routing"; }

    public override void OnMessage(string from, string message){
        if (message.StartsWith("bless")){
            Whisper("ShadowFlowers", "Please deliver a blessing to the hall.");
        }
    }
}
