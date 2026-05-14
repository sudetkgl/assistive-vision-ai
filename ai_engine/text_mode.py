import cv2
import time
import re
import numpy as np
import easyocr
from PIL import Image, ImageDraw, ImageFont

try:
    from speech import speak, stop_speaking
except Exception:
    from ai_engine.speech import speak, stop_speaking

CAMERA_INDEX = 0
FRAME_SIZE = (1280, 720)

reader = easyocr.Reader(["tr", "en"], gpu=False)

def draw_text(frame, text, pos, size=24, color=(255, 255, 255)):
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
    draw.text(pos, text, font=font, fill=color)
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

def clean_line(text):
    text = text.strip()
    text = re.sub(r"[^A-Za-zÇĞİÖŞÜçğıöşü0-9.,:;!?()\- ]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text

def correct_turkish_ocr(text):
    if not text:
        return ""

    fixes = {
        "OLAGAN": "OLAĞAN",
        "OLAGANÜSTÜ": "OLAĞANÜSTÜ",
        "OLAGANUSTU": "OLAĞANÜSTÜ",
        "OLAĞANUSTU": "OLAĞANÜSTÜ",
        "BIR ": "BİR ",
        " BIR": " BİR",
        " COK ": " ÇOK ",
        " COK": " ÇOK",
        "GUVEN": "GÜVEN",
        "YUZDE": "YÜZDE",
    }

    fixed = text
    upper = fixed.upper()
    for wrong, right in fixes.items():
        upper = upper.replace(wrong, right)

    # Hepsi büyük harfse daha doğal okunsun
    if upper.isupper():
        fixed = upper.title()
    else:
        fixed = upper

    return fixed

def prepare_for_speech(text):
    text = correct_turkish_ocr(text)

    # TTS telaffuz düzeltmeleri
    pronunciation = {
        "Stefan Zweig": "Ştefan Tsvayg",
        "STEFAN ZWEIG": "Ştefan Tsvayg",
        "Zweig": "Tsvayg",
        "ZWEIG": "Tsvayg",
    }

    for wrong, right in pronunciation.items():
        text = text.replace(wrong, right)

    return text

def looks_bad(text, conf):
    if not text or len(text) <= 2:
        return True
    letters = re.findall(r"[A-Za-zÇĞİÖŞÜçğıöşü]", text)
    if len(letters) < 3 and conf < 0.75:
        return True
    if conf < 0.45:
        return True
    return False

def crop_roi(frame):
    h, w = frame.shape[:2]
    x1 = int(w * 0.12)
    y1 = int(h * 0.18)
    x2 = int(w * 0.88)
    y2 = int(h * 0.88)
    return frame[y1:y2, x1:x2], (x1, y1, x2, y2)

def preprocess_variants(img):
    variants = [img]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.bilateralFilter(gray, 7, 50, 50)
    sharp = cv2.addWeighted(gray, 1.7, cv2.GaussianBlur(gray, (0, 0), 3), -0.7, 0)
    variants.append(cv2.cvtColor(sharp, cv2.COLOR_GRAY2BGR))
    up = cv2.resize(sharp, None, fx=1.7, fy=1.7, interpolation=cv2.INTER_CUBIC)
    variants.append(cv2.cvtColor(up, cv2.COLOR_GRAY2BGR))
    return variants

def sort_results(results):
    items = []
    for bbox, txt, conf in results:
        txt = clean_line(txt)
        if looks_bad(txt, conf):
            continue
        y = min(p[1] for p in bbox)
        x = min(p[0] for p in bbox)
        items.append((y, x, conf, txt))

    items.sort(key=lambda t: (t[0], t[1]))

    lines, seen = [], set()
    for _, _, conf, txt in items:
        key = txt.upper()
        if key in seen:
            continue
        seen.add(key)
        lines.append((conf, txt))
    return lines

def run_ocr_once(frame):
    roi, _ = crop_roi(frame)
    best_lines = []
    best_score = -1

    for img in preprocess_variants(roi):
        results = reader.readtext(
            img,
            detail=1,
            paragraph=False,
            decoder="beamsearch",
            contrast_ths=0.05,
            adjust_contrast=0.7,
            text_threshold=0.55,
            low_text=0.30,
            link_threshold=0.35,
        )

        lines = sort_results(results)
        if not lines:
            continue

        avg_conf = sum(c for c, _ in lines) / len(lines)
        char_count = sum(len(t) for _, t in lines)
        score = avg_conf * 2 + len(lines) * 0.3 + char_count * 0.01

        if score > best_score:
            best_score = score
            best_lines = lines

    return best_lines

def professional_scan(cap):
    all_candidates = []

    for _ in range(5):
        ok, frame = cap.read()
        if not ok or frame is None:
            continue
        frame = cv2.resize(frame, FRAME_SIZE)
        lines = run_ocr_once(frame)
        if lines:
            all_candidates.append(lines)
        time.sleep(0.12)

    if not all_candidates:
        return []

    return max(all_candidates, key=lambda lines: sum(c for c, _ in lines) / len(lines) + len(lines) * 0.2)

def build_text(lines):
    raw = " ".join(t for _, t in lines)
    raw = re.sub(r"\s+", " ", raw).strip()
    corrected = correct_turkish_ocr(raw)
    spoken = prepare_for_speech(raw)
    return corrected, spoken

def draw_ui(frame, last_text):
    frame = cv2.resize(frame, FRAME_SIZE)
    h, w = frame.shape[:2]
    _, (x1, y1, x2, y2) = crop_roi(frame)

    cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 3)
    cv2.rectangle(frame, (0, 0), (w, 125), (20, 20, 20), -1)

    frame = draw_text(frame, "Assistive Vision - Profesyonel Metin Okuma", (30, 25), 28)
    frame = draw_text(frame, "SPACE: Metni oku | R: Tekrar oku | S: Sesi sustur | ESC: Çıkış", (30, 68), 24, (120, 255, 120))
    frame = draw_text(frame, "Yazıyı yeşil çerçevenin içine alın ve kamerayı sabit tutun.", (30, 100), 20, (230, 230, 230))

    if last_text:
        cv2.rectangle(frame, (0, h - 90), (w, h), (20, 20, 20), -1)
        frame = draw_text(frame, last_text[:105], (30, h - 55), 24)

    return frame

def main():
    cap = cv2.VideoCapture(CAMERA_INDEX)
    if not cap.isOpened():
        print("Kamera açılamadı.")
        return

    time.sleep(2)
    for _ in range(10):
        cap.read()

    print("--- Profesyonel OCR metin okuma başladı ---")
    print("SPACE: metni oku | R: tekrar | S: sustur | ESC: çıkış")

    last_screen_text = ""
    last_spoken_text = ""

    speak("Metin okuma modu hazır. Yazıyı yeşil çerçevenin içine alın ve boşluk tuşuna basın.")

    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            continue

        shown = draw_ui(frame, last_screen_text)
        cv2.imshow("Assistive Vision - Profesyonel Metin Okuma", shown)

        key = cv2.waitKey(1) & 0xFF

        if key == 27:
            stop_speaking()
            break

        elif key == ord(" "):
            stop_speaking()
            print("\n--- Profesyonel OCR taraması başladı ---")
            lines = professional_scan(cap)

            if not lines:
                last_screen_text = "Okunabilir metin bulunamadı. Yazıyı daha net gösterin."
                last_spoken_text = last_screen_text
                print(last_screen_text)
                speak(last_spoken_text)
                continue

            for conf, line in lines:
                print(f"{conf:.2f} | {line}")

            last_screen_text, last_spoken_text = build_text(lines)

            print("Ekrana yazılan:", last_screen_text)
            print("Sesli okunan:", last_spoken_text)

            speak(last_spoken_text)

        elif key == ord("r"):
            stop_speaking()
            if last_spoken_text:
                speak(last_spoken_text)

        elif key == ord("s"):
            stop_speaking()

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
