from ultralytics import YOLO
import cv2
import easyocr

model = YOLO("yolov8n.pt")
reader = easyocr.Reader(['tr', 'en'])

cap = cv2.VideoCapture(0)

frame_count = 0
confidence_threshold = 0.55

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

last_detected_messages = []
last_detected_texts = []
last_results = None

def get_position(x_center, frame_width):
    if x_center < frame_width / 3:
        return "sol"
    elif x_center < 2 * frame_width / 3:
        return "orta"
    else:
        return "sağ"

cv2.namedWindow("AI Vision Assistant + OCR", cv2.WINDOW_NORMAL)

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame_count += 1

    # Sabit boyut kullan
    frame = cv2.resize(frame, (640, 480))
    display_frame = frame.copy()

    # YOLO her 8 karede bir çalışsın
    if frame_count % 8 == 0:
        results = model(frame, imgsz=320, verbose=False)
        last_results = results

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

                detected_messages.append(
                    f"{position} tarafta {category} algılandı ({label}, {conf:.2f})"
                )

        if detected_messages != last_detected_messages:
            last_detected_messages = detected_messages
            if detected_messages:
                print("\n--- Algılanan Nesneler ---")
                for msg in detected_messages:
                    print(msg)

    # Son sonuç varsa kutuları çiz
    if last_results is not None:
        display_frame = last_results[0].plot()

    # OCR daha seyrek çalışsın
    if frame_count % 30 == 0:
        ocr_frame = cv2.resize(frame, (480, 320))
        ocr_results = reader.readtext(ocr_frame)
        detected_texts = []

        for item in ocr_results:
            text = item[1].strip()
            score = item[2]
            if score > 0.60 and len(text) > 1:
                detected_texts.append(text)

        detected_texts = detected_texts[:2]

        if detected_texts != last_detected_texts:
            last_detected_texts = detected_texts
            if detected_texts:
                print("\n--- Algılanan Metinler ---")
                for text in detected_texts:
                    print(text)

    cv2.imshow("AI Vision Assistant + OCR", display_frame)

    key = cv2.waitKey(1)
    if key == 27:
        break

cap.release()
cv2.destroyAllWindows()