import cv2
import time
import threading
import queue
from flask import Flask, Response

app = Flask(__name__)

print("Initializing cameras...")

cap2 = cv2.VideoCapture('/dev/v4l/by-id/usb-Arducam_Technology_Co.__Ltd._Arducam_IMX477_HQ_Camera_UC517-video-index0')
cap2.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
cap2.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap2.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
cap2.set(cv2.CAP_PROP_FPS, 30)
time.sleep(3)
for _ in range(30): cap2.read()

cap4 = cv2.VideoCapture('/dev/v4l/by-id/usb-webcamvendor_SK_series1_20220325JWGD2093-video-index0')
cap4.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
cap4.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap4.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
cap4.set(cv2.CAP_PROP_FPS, 30)
time.sleep(3)
for _ in range(30): cap4.read()

print(f"Arducam:  {cap2.get(cv2.CAP_PROP_FRAME_WIDTH)}x{cap2.get(cv2.CAP_PROP_FRAME_HEIGHT)} @ {cap2.get(cv2.CAP_PROP_FPS)}fps")
print(f"SK Wrist: {cap4.get(cv2.CAP_PROP_FRAME_WIDTH)}x{cap4.get(cv2.CAP_PROP_FRAME_HEIGHT)} @ {cap4.get(cv2.CAP_PROP_FPS)}fps")

# Shared latest frames
latest = {'cam2': None, 'cam4': None}
fps_data = {
    'cam2': {'count': 0, 'time': time.time(), 'val': 0.0},
    'cam4': {'count': 0, 'time': time.time(), 'val': 0.0},
}

def read_cam2():
    while True:
        ret, frame = cap2.read()
        if ret:
            fps_data['cam2']['count'] += 1
            elapsed = time.time() - fps_data['cam2']['time']
            if elapsed >= 1.0:
                fps_data['cam2']['val'] = fps_data['cam2']['count'] / elapsed
                fps_data['cam2']['count'] = 0
                fps_data['cam2']['time'] = time.time()
            latest['cam2'] = frame.copy()

def read_cam4():
    while True:
        ret, frame = cap4.read()
        if ret:
            fps_data['cam4']['count'] += 1
            elapsed = time.time() - fps_data['cam4']['time']
            if elapsed >= 1.0:
                fps_data['cam4']['val'] = fps_data['cam4']['count'] / elapsed
                fps_data['cam4']['count'] = 0
                fps_data['cam4']['time'] = time.time()
            latest['cam4'] = frame.copy()

threading.Thread(target=read_cam2, daemon=True).start()
threading.Thread(target=read_cam4, daemon=True).start()

def stream(cam_key, label, color):
    while True:
        frame = latest[cam_key]
        if frame is None:
            time.sleep(0.01)
            continue
        fps = fps_data[cam_key]['val']
        fps_color = (0,255,0) if fps >= 25 else (0,165,255)
        cv2.putText(frame, f"{label} | {fps:.1f} FPS",
            (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)
        _, buf = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        yield (b'--frame\r\nContent-Type: image/jpeg\r\n\r\n'
               + buf.tobytes() + b'\r\n')

@app.route('/stream2')
def s2():
    return Response(stream('cam2', 'Workspace', (0,255,0)),
        mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/stream4')
def s4():
    return Response(stream('cam4', 'Wrist', (0,165,255)),
        mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/')
def index():
    return '''
    <html>
    <head>
        <title>Robot Camera Preview</title>
        <style>
            body { background:#111; margin:0; padding:20px;
                   display:flex; flex-direction:column;
                   align-items:center; font-family:sans-serif; }
            h2 { color:white; }
            .cams { display:flex; gap:20px; flex-wrap:wrap;
                    justify-content:center; }
            .cam { text-align:center; }
            .cam h3 { margin:5px 0; }
            .green { color:#00ff00; }
            .orange { color:#ffa500; }
            img { border-radius:8px; }
        </style>
    </head>
    <body>
        <h2>🤖 Robot Live Preview</h2>
        <div class="cams">
            <div class="cam">
                <h3 class="green">📷 Workspace (Arducam)</h3>
                <img src="/stream2" width=640
                     style="border:2px solid #00ff00">
            </div>
            <div class="cam">
                <h3 class="orange">📷 Wrist (SK series1)</h3>
                <img src="/stream4" width=640
                     style="border:2px solid #ffa500">
            </div>
        </div>
        <p style="color:#555;margin-top:15px">
            Both cameras @ 30fps | No data saved | Ctrl+C to stop
        </p>
    </body>
    </html>
    '''

print("Open browser → http://localhost:5000")
print("Nothing saved to disk ✅")
print("Press Ctrl+C to stop")
app.run(host='0.0.0.0', port=5000, threaded=True)
