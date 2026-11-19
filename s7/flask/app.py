import os
import re
import socket

import psycopg
import redis
from flask import Flask, jsonify, request

app = Flask(__name__)
cache = redis.Redis.from_url(
    os.environ["REDIS_URL"], socket_connect_timeout=2, socket_timeout=2
)


def database():
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
        options="-c statement_timeout=3000",
    )


@app.errorhandler(psycopg.Error)
@app.errorhandler(redis.RedisError)
def dependency_failed(error):
    app.logger.error("Dependency unavailable: %s", type(error).__name__)
    return jsonify(error="Database or cache unavailable"), 503


@app.get("/")
def home():
    return """<h1>Sports fixtures lab companion</h1>
<p><a href="/fixtures">PostgreSQL fixtures and Redis visit counter</a></p>
<form action="/fixtures" method="post">
<label>Fixture <input name="name" maxlength="60" required></label>
<button>Save</button>
</form>"""


@app.get("/health")
def health():
    with database() as db:
        db.execute("SELECT 1").fetchone()
    cache.ping()
    return jsonify(postgres="ok", redis="ok")


@app.route("/fixtures", methods=["GET", "POST"])
def fixtures():
    with database() as db:
        if request.method == "POST":
            name = request.form.get("name", "")
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 _-]{0,59}", name):
                return jsonify(error="Invalid fixture name"), 400
            db.execute("INSERT INTO fixtures VALUES (%s) ON CONFLICT DO NOTHING", (name,))
            return jsonify(saved=name), 201
        names = [row[0] for row in db.execute("SELECT name FROM fixtures ORDER BY name")]
    return jsonify(fixtures=names, visits=cache.incr("fixture-reads"), instance=socket.gethostname())
