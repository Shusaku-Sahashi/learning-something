import os
import time

import redis
from flask import Flask, jsonify

app = Flask(__name__)

REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", "")
APP_VERSION = os.environ.get("APP_VERSION", "dev")

r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD or None,
    decode_responses=True,
    socket_connect_timeout=2,
)


@app.get("/")
def index():
    hits = r.incr("hits")
    return jsonify(message="Hello from learning-something!", version=APP_VERSION, hits=hits)


@app.get("/health")
def health():
    r.ping()
    return jsonify(status="ok"), 200


@app.get("/slow")
def slow():
    # docker stats / logs --since の練習用にわざと重い処理を再現するエンドポイント
    time.sleep(3)
    return jsonify(status="done, that took a while"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
