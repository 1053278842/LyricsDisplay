from flask import Flask, request, jsonify
from flask_cors import CORS
import json

app = Flask(__name__)
CORS(app)  # 启用 CORS

latest_lyrics = None  # 用于存储最新的歌词数据

# 处理歌词上传的接口
@app.route('/upload', methods=['POST'])
def upload_lyrics():
    global latest_lyrics
    try:
        data = request.json  # 获取 JSON 数据
        latest_lyrics = data
        print("歌曲:接收成功!")
        with open("lyrics.json", "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4)  # 存储到文件
        return jsonify({"status": "success", "message": "Lyrics received!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/latest_lyrics', methods=['GET'])
def get_latest_lyrics():
    return latest_lyrics

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5588)  # 监听局域网
