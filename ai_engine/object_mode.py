from ultralytics import YOLO
import cv2
from speech import speak

model = YOLO("models/yolov8n.pt")
cap = cv2.VideoCapture(0)

confidence_threshold = 0.35

label_to_message = {
    "person": "İnsan var",
    "car": "Araç var",
    "bus": "Araç var",
    "truck": "Araç var",
    "motorcycle": "Araç var",
    "bicycle": "Araç var",
    "chair": "Engel var",
    "bench": "Engel var",
    "couch": "Engel var",
    "bed": "Engel var",
    "potted plant": "Engel var",
    "bottle": "Şişe var",
    "cup": "Bardak var",
    "cell phone": "Telefon var",
    "book": "Kitap var",
    "laptop": "Laptop var"
}

def get_position(x_center, frame_width):
    if x_center < frame_width / 3:
        return "sol tarafta"
    elif x_center < 2 * frame_width / 3:
        return "orta tarafta"
    return "sağ tarafta"

last_results = None

while True:
    ret, frame = cap.read()
    if not ret:
        print("Kamera görüntüsü alınamadı")
        break

    frame = cv2.resize(frame, (640, 480))
    display_frame = frame.copy()

    if last_results is not None:
        display_frame = last_results[0].plot()

    cv2.putText(
        display_frame,
        "SPACE: Analiz et | ESC: Cikis",
        (10, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 0),
        2
    )

    cv2.imshow("Object Mode", display_frame)
    key = cv2.waitKey(1)

    if key == 27:  # ESC
        break

    elif key == 32:  # SPACE
        results = model(frame, imgsz=320, verbose=False)
        last_results = results

        boxes = results[0].boxes
        names = model.names

        messages = []

        if boxes is not None:
            for box in boxes:
                cls_id = int(box.cls[0].item())
                conf = float(box.conf[0].item())
                label = names[cls_id]

                if conf < confidence_threshold:
                    continue

                if label not in label_to_message:
                    continue

                x1, y1, x2, y2 = box.xyxy[0].tolist()
                x_center = (x1 + x2) / 2
                position = get_position(x_center, frame.shape[1])

                spoken_text = f"{position} {label_to_message[label]}"
                messages.append((conf, spoken_text, label))

        if messages:
            messages.sort(key=lambda x: -x[0])
            best_message = messages[0][1]

            print("\n--- Analiz Sonucu ---")
            for _, msg, label in messages:
                print(f"{label} -> {msg}")

            speak(best_message)
        else:
            print("\n--- Analiz Sonucu ---")
            print("Anlamli nesne algilanamadi")
            speak("Anlamlı nesne algılanamadı")

cap.release()
cv2.destroyAllWindows()
