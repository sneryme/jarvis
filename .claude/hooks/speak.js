const fs = require("fs"), os = require("os"), path = require("path"), { spawn } = require("child_process");
const FLAG = "C:/Users/win11/jarvis/.claude/voice-on";
let d = "";
process.stdin.on("data", c => d += c);
process.stdin.on("end", () => {
  try {
    if (!fs.existsSync(FLAG)) return;
    const inp = JSON.parse(d);
    const lines = fs.readFileSync(inp.transcript_path, "utf8").trim().split("\n");
    let text = "";
    for (let i = lines.length - 1; i >= 0 && !text; i--) {
      let e; try { e = JSON.parse(lines[i]); } catch { continue; }
      if (e.type === "user" && !(e.message && Array.isArray(e.message.content) && e.message.content[0] && e.message.content[0].type === "tool_result")) break;
      if (e.type === "assistant" && e.message && Array.isArray(e.message.content))
        text = e.message.content.filter(b => b.type === "text").map(b => b.text).join(" ");
    }
    if (!text) return;
    text = text.replace(/```[\s\S]*?```/g, " ").replace(/[*_#`>|\[\]()]/g, " ")
               .replace(/https?:\/\/\S+/g, " ").replace(/[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]/gu, " ")
               .replace(/\s+/g, " ").trim().slice(0, 700);
    const f = path.join(os.tmpdir(), "jarvis-say.txt");
    fs.writeFileSync(f, text, "utf8");
    const ps = "Add-Type -AssemblyName System.Speech; $s=New-Object System.Speech.Synthesis.SpeechSynthesizer; " +
      "$v=$s.GetInstalledVoices()|?{$_.VoiceInfo.Culture.Name -eq 'ru-RU'}|select -First 1; if($v){$s.SelectVoice($v.VoiceInfo.Name)}; " +
      "$s.Rate=1; $s.Speak([IO.File]::ReadAllText('" + f.replace(/\\/g, "/") + "'))";
    spawn("powershell", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", ps], { detached: true, stdio: "ignore" }).unref();
  } catch (e) {}
});