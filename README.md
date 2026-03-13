# AI-Supported Real-Time Mobile Vision Assistant

## Project Overview

This project is a capstone project developed to assist visually impaired individuals in perceiving their surroundings more independently.

The system uses a mobile camera to detect nearby objects, read visible text, and provide audio feedback to the user.

The goal is to create a simple assistive vision system that can recognize important environmental elements and communicate them through speech.

---

## Features

### Object Detection Mode

The system detects objects in the camera view and provides spoken feedback about their location.

Example outputs:

* "Sol tarafta insan var"
* "Orta tarafta engel var"
* "Sağ tarafta araç var"

### Text Reading Mode

The system detects and reads visible text using OCR technology.

Example outputs:

* "EXIT"
* "WC"
* "ODA 203"

### Speech Feedback

Detected objects and text are converted into voice output so visually impaired users can understand their surroundings.

---

## Technologies Used

* Python
* YOLOv8 (Object Detection)
* OpenCV (Camera Processing)
* EasyOCR (Text Recognition)
* macOS `say` command (Speech Output)

---

## Project Structure

assistivevision
│
├── ai_engine
│   ├── object_mode.py
│   ├── text_mode.py
│   └── speech.py
│
├── models
│   └── yolov8n.pt
│
├── requirements.txt
└── README.md

---

## How to Run

### Object Detection Mode

Run the object detection module:

python ai_engine/object_mode.py

---

### Text Reading Mode

Run the text reading module:

python ai_engine/text_mode.py

---

## Student Responsibilities

### Student 1 – AI Development

* AI environment setup
* YOLO object detection integration
* OCR integration
* Speech feedback system
* AI prototype development and testing

### Student 2 – Mobile Application Development

* Mobile application development (Flutter / Android)
* Camera interface for the mobile app
* UI/UX design
* Integration of AI output into the mobile application
* Mobile demo preparation

---

## Project Goal

The aim of this project is to develop an assistive vision system that helps visually impaired individuals detect nearby objects and read text through real-time AI analysis and audio feedback.

The system is designed as a prototype that can later be integrated into a mobile application.

## Future Improvements

- Real-time mobile integration with Flutter
- Improved obstacle detection for outdoor navigation
- Distance estimation for safer walking assistance
- Integration with GPS for navigation support
- Custom training for better detection of everyday objects
