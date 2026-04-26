import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import time
from collections import deque
import threading
import asyncio
import websockets
from flask import Flask, Response
import mmap

# --- MediaPipe Config ---
model_path = r'hand_landmarker.task'
base_options = python.BaseOptions(model_asset_path=model_path)
options = vision.HandLandmarkerOptions(
    base_options=base_options,
    running_mode=vision.RunningMode.VIDEO,
    num_hands=1
)
detector = vision.HandLandmarker.create_from_options(options)

current_gesture = 0
latest_frame = None
x_history = deque(maxlen=8)
app = Flask(__name__)

# --- Shared Memory Setup ---
SHM_PATH = "/tmp/godot_frame.bin"
SHM_WIDTH = 320
SHM_HEIGHT = 240
SHM_CHANNELS = 3
SHM_FRAME_SIZE = SHM_WIDTH * SHM_HEIGHT * SHM_CHANNELS

with open(SHM_PATH, "wb") as f:
    f.write(b'\x00' * (1 + SHM_FRAME_SIZE))

shm_file = open(SHM_PATH, "r+b")
shm = mmap.mmap(shm_file.fileno(), 1 + SHM_FRAME_SIZE)

def write_shm(frame):
    small = cv2.resize(frame, (SHM_WIDTH, SHM_HEIGHT))
    rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
    shm.seek(0)
    shm.write(b'\x00')          # dirty
    shm.write(rgb.tobytes())
    shm.seek(0)
    shm.write(b'\x01')          # clean
    shm.flush()

@app.route('/')
def home(): return "Server LIVE. Video at /stream"

@app.route('/stream')
def stream():
    def generate():
        while True:
            if latest_frame is not None:
                _, buffer = cv2.imencode('.jpg', latest_frame)
                yield (b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')
            time.sleep(0.03)
    return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')

def is_fist(hand_landmarks):
    return all(hand_landmarks[t].y > hand_landmarks[p].y for t, p in [(8,6), (12,10), (16,14), (20,18)])

def video_worker():
    global current_gesture, latest_frame
    cap = cv2.VideoCapture(0)
    while cap.isOpened():
        success, frame = cap.read()
        if not success: break
        frame = cv2.flip(frame, 1)
        rgb_frame = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        detection_result = detector.detect_for_video(rgb_frame, int(time.time() * 1000))
        if detection_result.hand_landmarks:
            hand_lms = detection_result.hand_landmarks[0]
            x_history.append(hand_lms[0].x)
            if is_fist(hand_lms):
                current_gesture = 3
            elif len(x_history) == x_history.maxlen:
                diff = x_history[-1] - x_history[0]
                if diff > 0.12: current_gesture = 1
                elif diff < -0.12: current_gesture = 2
                else: current_gesture = 0
            else: current_gesture = 0
        else:
            current_gesture = 0
            x_history.clear()
        cv2.putText(frame, f"ID: {current_gesture}", (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        latest_frame = frame
        write_shm(frame)  # write to shared memory for godot
    cap.release()

async def ws_handler(websocket):
    global current_gesture
    last_sent = 0
    last_event_time = 0
    COOLDOWN = 0.6
    try:
        while True:
            now = time.time()
            if current_gesture != 0 and current_gesture != last_sent:
                if now - last_event_time > COOLDOWN:
                    await websocket.send(str(current_gesture))
                    last_sent = current_gesture
                    last_event_time = now
            if current_gesture == 0:
                last_sent = 0
            await asyncio.sleep(0.001)
    except:
        pass

async def main():
    threading.Thread(target=video_worker, daemon=True).start()
    threading.Thread(target=lambda: app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False), daemon=True).start()
    async with websockets.serve(ws_handler, "0.0.0.0", 5001):
        print("\n🚀 SYSTEMS LIVE WITH SWIPE FIX")
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutting down...")

# Terminal Run
# python D26-1_Computer_Vision/handEfficient2.py
# Test Video
# http://localhost:5000/stream
# JavaScript Test for output
# const ws = new WebSocket('ws://localhost:5001'); ws.onmessage = (e) => console.log(e.data);
