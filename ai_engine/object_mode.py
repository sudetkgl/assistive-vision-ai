import cv2
import time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from ultralytics import YOLO

try:
    from speech import speak, stop_speaking
except Exception:
    from ai_engine.speech import speak, stop_speaking

CAMERA_INDEX = 0
MODEL_PATH = "yolov8n.pt"

TR_NAMES = {
    "person": "insan",
    "cell phone": "telefon",
    "laptop": "laptop",
    "keyboard": "klavye",
    "mouse": "fare",
    "book": "kitap",
    "bottle": "şişe",
    "cup": "bardak",
    "chair": "sandalye",
    "tv": "televizyon",
    "remote": "kumanda",
    "backpack": "çanta",
    "handbag": "çanta",
    "dog": "köpek",
    "cat": "kedi",
}

def tr_label(name):
    return TR_NAMES.get(name, name)

def ascii_text(text):
    return (
        text.replace("ş", "s").replace("Ş", "S")
            .replace("ı", "i").replace("İ", "I")
            .replace("ğ", "g").replace("Ğ", "G")
            .replace("ü", "u").replace("Ü", "U")
            .replace("ö", "o").replace("Ö", "O")
            .replace("ç", "c").replace("Ç", "C")
    )

def get_position(x1, x2, width):
    center = (x1 + x2) / 2
    if center < width * 0.33:
        return "solda"
    elif center > width * 0.66:
        return "sağda"
    return "tam karşıda"

def get_distance(box_area, frame_area):
    ratio = box_area / frame_area
    if ratio > 0.35:
        return "çok yakın"
    elif ratio > 0.15:
        return "yakın"
    return "ileride"

def analyse_frame(model, frame):
    results = model(frame, verbose=False)[0]
    detections = []
    h, w = frame.shape[:2]
    frame_area = h * w

    for box in results.boxes:
        conf = float(box.conf[0])
        if conf < 0.45:
            continue

        cls = int(box.cls[0])
        name = model.names[cls]
        label = tr_label(name)

        x1, y1, x2, y2 = map(int, box.xyxy[0])
        area = max(1, (x2 - x1) * (y2 - y1))

        position = get_position(x1, x2, w)
        distance = get_distance(area, frame_area)

        detections.append({
            "label": label,
            "original": name,
            "conf": conf,
            "box": (x1, y1, x2, y2),
            "position": position,
            "distance": distance
        })

    detections.sort(key=lambda d: d["conf"], reverse=True)
    return detections[:5]

def build_message(detections):
    if not detections:
        return "Herhangi bir nesne algılanamadı."

    first = detections[0]
    percent = int(first["conf"] * 100)

    if len(detections) == 1:
        return f"{first['position']}, {first['distance']}, {first['label']}. Güven oranı yüzde {percent}."

    labels = ", ".join([d["label"] for d in detections[:3]])
    return f"Algılanan nesneler: {labels}. En belirgin nesne {first['position']}, {first['distance']}, {first['label']}. Güven oranı yüzde {percent}."

def draw_turkish_text(frame, text, pos, size=24):
    img = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(img)

    font_paths = [
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]

    font = None
    for fp in font_paths:
        try:
            font = ImageFont.truetype(fp, size)
            break
        except Exception:
            pass

    if font is None:
        font = ImageFont.load_default()

    draw.text(pos, text, font=font, fill=(255, 255, 255))
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


def draw(frame, detections, last_message, continuous):
    overlay = frame.copy()
    h, w = overlay.shape[:2]

    cv2.rectangle(overlay, (0, 0), (w, 92), (15, 15, 15), -1)
    cv2.putText(overlay, "Assistive Vision - Object Mode", (15, 32),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255,255,255), 2)
    cv2.putText(overlay, "SPACE: analyse | R: repeat | S: stop | C: continuous | ESC: exit",
                (15, 68), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (230,230,230), 1)
    cv2.putText(overlay, f"Continuous: {'ON' if continuous else 'OFF'}",
                (w - 190, 68), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (230,230,230), 1)

    for i, d in enumerate(detections):
        x1, y1, x2, y2 = d["box"]
        cv2.rectangle(overlay, (x1, y1), (x2, y2), (0, 255, 255), 3)

        label_line = f"{i+1}. {ascii_text(d['label'])} ({d['original']}) {d['conf']:.2f}"
        info_line = f"{d['position']} - {d['distance']}"

        y = max(120, y1 - 42)
        cv2.rectangle(overlay, (x1, y - 25), (min(w-5, x1 + 360), y + 25), (15,15,15), -1)
        cv2.putText(overlay, label_line, (x1 + 5, y - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.48, (255,255,255), 1)
        overlay = draw_turkish_text(overlay, info_line, (x1 + 5, y + 2), 18)

    cv2.rectangle(overlay, (0, h - 70), (w, h), (15, 15, 15), -1)
    screen_msg = last_message
    overlay = draw_turkish_text(overlay, screen_msg[:100], (15, h - 45), 24)

    return overlay

def main():
    model = YOLO(MODEL_PATH)

    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        print("Kamera acilamadi.")
        return

    time.sleep(2)
    for _ in range(10):
        cap.read()

    print("--- Object Mode Started ---")
    print("SPACE: analyse | R: repeat | S: stop | C: continuous | ESC: exit")

    last_detections = []
    last_message = "Nesne algılama hazır. Analiz için boşluk tuşuna basın."
    continuous = False
    last_time = 0

    speak(last_message)

    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            print("Kamera goruntusu alinamadi.")
            time.sleep(0.2)
            continue

        frame = cv2.resize(frame, (1280, 720))

        now = time.time()
        if continuous and now - last_time > 2.5:
            last_detections = analyse_frame(model, frame)
            last_message = build_message(last_detections)
            speak(last_message)
            last_time = now

        shown = draw(frame, last_detections, last_message, continuous)
        cv2.imshow("Object Mode", shown)

        key = cv2.waitKey(1) & 0xFF

        if key == 27:
            stop_speaking()
            break

        elif key == ord(" "):
            stop_speaking()
            last_detections = analyse_frame(model, frame)
            last_message = build_message(last_detections)
            print(last_message)
            speak(last_message)

        elif key == ord("r"):
            stop_speaking()
            speak(last_message)

        elif key == ord("s"):
            stop_speaking()

        elif key == ord("c"):
            continuous = not continuous
            stop_speaking()
            last_message = "Sürekli nesne algılama açıldı." if continuous else "Sürekli nesne algılama kapatıldı."
            speak(last_message)

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
