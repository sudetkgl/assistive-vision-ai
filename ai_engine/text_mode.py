import cv2
import easyocr
from speech import speak

reader = easyocr.Reader(['tr', 'en'])
cap = cv2.VideoCapture(0)

last_texts = []

while True:
    ret, frame = cap.read()
    if not ret:
        print("Kamera görüntüsü alınamadı")
        break

    frame = cv2.resize(frame, (640, 480))
    display_frame = frame.copy()

    cv2.putText(
        display_frame,
        "SPACE: Metni oku | ESC: Cikis",
        (10, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 0),
        2
    )

    cv2.imshow("Text Reading Mode", display_frame)
    key = cv2.waitKey(1)

    if key == 27:  # ESC
        break

    elif key == 32:  # SPACE
        ocr_frame = cv2.resize(frame, (640, 480))
        results = reader.readtext(ocr_frame)

        detected_texts = []

        for item in results:
            text = item[1].strip()
            score = item[2]

            if score > 0.50 and len(text) > 1:
                detected_texts.append((score, text))

        print("\n--- OCR Sonucu ---")

        if detected_texts:
            detected_texts.sort(reverse=True)
            top_texts = [text for _, text in detected_texts[:3]]

            for text in top_texts:
                print(text)

            spoken_text = " ".join(top_texts)
            speak(spoken_text)
            last_texts = top_texts
        else:
            print("Metin algilanamadi")
            speak("Metin algılanamadı")

cap.release()
cv2.destroyAllWindows()
