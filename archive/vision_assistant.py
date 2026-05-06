from ultralytics import YOLO
import cv2
import time
from speech import speak

model = YOLO("models/yolov8n.pt")
cap = cv2.VideoCapture(0)

frame_count = 0
confidence_threshold = 0.35

assistive_categories = {
    "person": ("İnsan", 2),
    "car": ("Araç", 1),
    "bus": ("Araç", 1),
    "truck": ("Araç", 1),
    "motorcycle": ("Araç", 1),
    "bicycle": ("Araç", 1),
    "chair": ("Engel", 3),
    "bench": ("Engel", 3),
    "couch": ("Engel", 3),
    "bed": ("Engel", 3),
    "potted plant": ("Engel", 3),
    "bottle": ("Küçük nesne", 4),
    "cup": ("Küçük nesne", 4),
    "cell phone": ("Kişisel eşya", 4),
    "book": ("Kişisel eşya", 4),
    "laptop": ("Elektronik eşya", 4)
}

last_results = None
last_spoken_message = ""
last_spoken_time = 0
speech_cooldown = 3.0

cv2.namedWindow("AI Vision Assistant", cv2.WINDOW_NORMAL)

def get_position(x_center, frame_width):
    if x_center < frame_width / 3:
        return "sol"
    elif x_center < 2 * frame_width / 3:
        return "orta"
    return "sağ"

while True:
    ret, frame = cap.read()
    if not ret:
        print("Kamera görüntüsü alınamadı")
        break

    frame_count += 1
    frame = cv2.resize(frame, (640, 480))
    display_frame = frame.copy()

    # Biraz daha dengeli ayar
    if frame_count % 12 == 0:
        results = model(frame, imgsz=320, verbose=False)
        last_results = results

        boxes = results[0].boxes
        names = model.names
        candidates = []

        if boxes is not None:
            for box in boxes:
                cls_id = int(box.cls[0].item())
                conf = float(box.conf[0].item())
                label = names[cls_id]

                if conf < confidence_threshold:
                    continue

                if label not in assistive_categories:
                    continue

                category, priority = assistive_categories[label]

                x1, y1, x2, y2 = box.xyxy[0].tolist()
                x_center = (x1 + x2) / 2
                position = get_position(x_center, frame.shape[1])

                candidates.append({
                    "label": label,
                    "category": category,
                    "priority": priority,
                    "confidence": conf,
                    "position": position
                })

        # Öncelikli ama insan dışı nesnelere de fırsat veren seçim
        chosen = None

        if candidates:
            candidates.sort(key=lambda x: (x["priority"], -x["confidence"]))

            # İlk önce araç / engel / küçük nesne varsa onu seç
            for item in candidates:
                if item["label"] != "person":
                    chosen = item
                    break

            # Hiçbiri yoksa insan seç
            if chosen is None:
                chosen = candidates[0]

            message = f"{chosen['position']} tarafta {chosen['category']} var"
            print(message, f"({chosen['label']}, {chosen['confidence']:.2f})")

            current_time = time.time()
            if (
                message != last_spoken_message
                and current_time - last_spoken_time > speech_cooldown
            ):
                speak(message)
                last_spoken_message = message
                last_spoken_time = current_time

    # Kutu çizimli görüntüyü göster
    if last_results is not None:
        display_frame = last_results[0].plot()

    cv2.imshow("AI Vision Assistant", display_frame)

    key = cv2.waitKey(1)
    if key == 27:
        break

cap.release()
cv2.destroyAllWindows()
