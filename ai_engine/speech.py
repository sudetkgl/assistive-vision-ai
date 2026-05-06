import subprocess

def speak(text):
    safe_text = text.replace("'", "")
    subprocess.Popen(["say", safe_text])
