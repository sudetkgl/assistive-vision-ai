from ultralytics import YOLO
import cv2

model = YOLO("yolov8n.pt")
cap = cv2.VideoCapture(0)

frame_count = 0
confidence_threshold = 0.55

# COCO sınıflarını yardımcı kategorilere çevirme
assistive_categories = {
    "person": "İnsan",
    "car": "Araç",
    "bus": "Araç",
    "truck": "Araç",
    "motorcycle": "Araç",
    "bicycle": "Araç",
    "chair": "Engel",
    "bench": "Engel",
    "couch": "Engel",
    "bed": "Engel",
    "potted plant": "Engel",
    "bottle": "Küçük nesne",
    "cup": "Küçük nesne",
    "cell phone": "Kişisel eşya",
    "book": "Kişisel eşya",
    "laptop": "Elektronik eşya"
}


def get_position(x_center, frame_width):
    if x_center < frame_width / 3:
        return "sol"
    elif x_center < 2 * frame_width / 3:
        return "orta"
    else:
        return "sağ"


while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame_count += 1
    display_frame = frame.copy()

    if frame_count % 5 == 0:
        results = model(frame, imgsz=320, verbose=False)
        boxes = results[0].boxes
        names = model.names

        detected_messages = []

        if boxes is not None:
            for box in boxes:
                cls_id = int(box.cls[0].item())
                conf = float(box.conf[0].item())
                label = names[cls_id]

                if conf < confidence_threshold:
                    continue

                if label not in assistive_categories:
                    continue

                x1, y1, x2, y2 = box.xyxy[0].tolist()
                x_center = (x1 + x2) / 2
                position = get_position(x_center, frame.shape[1])
                category = assistive_categories[label]

                message = f"{position} tarafta {category} algılandı ({label}, {conf:.2f})"
                detected_messages.append(message)

        display_frame = results[0].plot()

        if detected_messages:
            print("\n--- Algılananlar ---")
            for msg in detected_messages:
                print(msg)

    cv2.imshow("AI Vision Assistant", display_frame)

    key = cv2.waitKey(1)
    if key == 27:
        break

cap.release()
cv2.destroyAllWindows()