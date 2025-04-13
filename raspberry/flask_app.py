from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import json

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")  # 允许跨域

@app.route('/upload', methods=['POST'])
def upload_lyrics():
    try:
        data = request.json  # 获取客户端上传的歌词 JSON 数据
        print("歌曲上传成功!")
        # 将数据保存到文件（可选）
        with open("lyrics.json", "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        # 将数据广播给所有已连接的 WebSocket 客户端
        socketio.emit('new_lyrics', data)
        return jsonify({"status": "success", "message": "Lyrics received and broadcast!"})
    except Exception as e:
        print("上传出错:", e)
        return jsonify({"status": "error", "message": str(e)}), 500

@socketio.on('connect')
def handle_connect():
    print("客户端已连接")

@socketio.on('disconnect')
def handle_disconnect():
    print("客户端已断开连接")

if __name__ == "__main__":
    socketio.run(app, host='0.0.0.0', port=5588)

