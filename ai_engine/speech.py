import platform
import subprocess

_current_process = None

def speak(text: str):
    global _current_process
    stop_speaking()

    text = (text or "").strip()
    if not text:
        return

    system = platform.system().lower()

    if system == "darwin":
        _current_process = subprocess.Popen(["say", "-v", "Yelda", "-r", "165", text])
    elif system == "linux":
        _current_process = subprocess.Popen(["espeak", "-v", "tr", "-s", "150", text])
    elif system == "windows":
        safe = text.replace("'", "")
        command = (
            "Add-Type -AssemblyName System.Speech; "
            "$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            f"$speak.Speak('{safe}')"
        )
        _current_process = subprocess.Popen(["powershell", "-Command", command])
    else:
        print(text)

def stop_speaking():
    global _current_process
    try:
        if _current_process and _current_process.poll() is None:
            _current_process.terminate()
    except Exception:
        pass
    _current_process = None

