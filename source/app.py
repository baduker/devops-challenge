import os

import psycopg2
from flask import Flask, jsonify
from prometheus_client import Counter, make_wsgi_app
from psycopg2.extras import RealDictCursor
from werkzeug.middleware.dispatcher import DispatcherMiddleware

app = Flask(__name__)

REQUEST_COUNT = Counter('app_requests_total', 'Total number of HTTP requests', ['endpoint', 'method', 'status_code'])
DB_QUERY_COUNT = Counter('db_query_total', 'Total number of database queries', ['query'])

# Database connection function
def get_db_connection():
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=os.getenv('DB_PORT', '5432'),
        dbname=os.getenv('DB_NAME', None),
        user=os.getenv('DB_USER', None),
        password=os.getenv('DB_PASSWORD', None),
        sslmode=os.getenv('DB_SSLMODE', 'require'),
        sslrootcert=os.getenv('SSL_ROOT_CERT', None)
    )
    return conn

@app.route('/')
def main():
    REQUEST_COUNT.labels(endpoint='/', method='GET', status_code='200').inc()
    return jsonify({"Message": "Hello, Sherpany!"})

@app.route('/users')
def get_users():
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            query = 'SELECT id, name, email FROM users'
            DB_QUERY_COUNT.labels(query=query).inc()
            cur.execute(query)
            users = cur.fetchall()
            REQUEST_COUNT.labels(endpoint='/users', method='GET', status_code='200').inc()
            return jsonify([dict(user) for user in users])
    finally:
        conn.close()

@app.route('/health')
def health_check():
    # Enable it to count the health check requests
    # Note: This can get pretty spammy since the liveliness and readiness probes
    # are called frequently
    # REQUEST_COUNT.labels(endpoint='/health', method='GET', status_code='200').inc()
    return jsonify({"status": "healthy"})

app.wsgi_app = DispatcherMiddleware(app.wsgi_app, {
    '/metrics': make_wsgi_app()
})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
