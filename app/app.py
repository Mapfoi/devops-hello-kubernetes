import os
import psycopg2
from flask import Flask, jsonify
from psycopg2 import OperationalError
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

# Инициализация Prometheus метрик
metrics = PrometheusMetrics(app)
metrics.info('app_info', 'Application info', version='1.0.0')



def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST'),
        port=os.getenv('DB_PORT', '5432'),
        database=os.getenv('DB_NAME'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD')
    )

def init_db():
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
        return True
    except Exception as e:
        print(f"DB init error: {e}")
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
