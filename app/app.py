import os
import time
import psycopg2
from flask import Flask, jsonify
from psycopg2 import OperationalError
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

metrics = PrometheusMetrics(app)
metrics.info('app_info', 'Application info', version='1.0.0')


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST'),
        port=os.getenv('DB_PORT', '5432'),
        database=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        connect_timeout=5,
    )


def init_db(retries=10, delay=3):
    """Retry DB init — DNS for MDB host can be briefly unavailable at pod start."""
    for attempt in range(1, retries + 1):
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('''
                CREATE TABLE IF NOT EXISTS visits (
                    id SERIAL PRIMARY KEY,
                    count INTEGER DEFAULT 0
                );
            ''')
            cur.execute("""
                INSERT INTO visits (id, count)
                VALUES (1, 0)
                ON CONFLICT (id) DO NOTHING;
            """)
            conn.commit()
            cur.close()
            conn.close()
            print("DB init OK")
            return True
        except Exception as e:
            print(f"DB init attempt {attempt}/{retries} failed: {e}")
            if attempt < retries:
                time.sleep(delay)
    return False


init_db()


@app.route('/')
def hello_world():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE visits SET count = count + 1 WHERE id = 1 RETURNING count;")
        current_count = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            "message": "Hello, DevOps from Yandex Cloud!",
            "visits": current_count,
            "status": "success"
        })
    except OperationalError as e:
        return jsonify({
            "error": "Database connection failed",
            "details": str(e)
        }), 500


@app.route('/health')
def health():
    return jsonify({"status": "healthy"})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
