from flask import Flask, jsonify, request
from flask_cors import CORS
import os
import logging
from datetime import datetime
from db import get_db_connection, init_db

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Environment info
ENV = os.getenv('ENVIRONMENT', 'dev')
VERSION = os.getenv('APP_VERSION', '1.0.0')

# Initialize database on startup
try:
    init_db()
    logger.info(f"Database initialized successfully for {ENV} environment")
except Exception as e:
    logger.error(f"Failed to initialize database: {str(e)}")
    # Don't crash the app, just log the error

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint for ALB target group"""
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({
            'status': 'healthy',
            'environment': ENV,
            'version': VERSION,
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 503

@app.route('/api/todos', methods=['GET'])
def get_todos():
    """Fetch all todos"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT id, title, completed, created_at FROM todos ORDER BY created_at DESC')
        todos = []
        for row in cur.fetchall():
            todos.append({
                'id': row[0],
                'title': row[1],
                'completed': row[2],
                'created_at': row[3].isoformat() if row[3] else None
            })
        cur.close()
        conn.close()
        return jsonify({
            'todos': todos,
            'count': len(todos),
            'environment': ENV
        }), 200
    except Exception as e:
        logger.error(f"Error fetching todos: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/todos', methods=['POST'])
def create_todo():
    """Create a new todo"""
    try:
        data = request.get_json()
        if not data or 'title' not in data:
            return jsonify({'error': 'Title is required'}), 400
        
        title = data['title']
        completed = data.get('completed', False)
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            'INSERT INTO todos (title, completed) VALUES (%s, %s) RETURNING id, created_at',
            (title, completed)
        )
        todo_id, created_at = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({
            'id': todo_id,
            'title': title,
            'completed': completed,
            'created_at': created_at.isoformat(),
            'environment': ENV
        }), 201
    except Exception as e:
        logger.error(f"Error creating todo: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/todos/<int:todo_id>', methods=['PUT'])
def update_todo(todo_id):
    """Update a todo"""
    try:
        data = request.get_json()
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Build dynamic update query
        updates = []
        values = []
        if 'title' in data:
            updates.append('title = %s')
            values.append(data['title'])
        if 'completed' in data:
            updates.append('completed = %s')
            values.append(data['completed'])
        
        if not updates:
            return jsonify({'error': 'No fields to update'}), 400
        
        values.append(todo_id)
        query = f"UPDATE todos SET {', '.join(updates)} WHERE id = %s RETURNING id, title, completed, created_at"
        
        cur.execute(query, values)
        row = cur.fetchone()
        if not row:
            return jsonify({'error': 'Todo not found'}), 404
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({
            'id': row[0],
            'title': row[1],
            'completed': row[2],
            'created_at': row[3].isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error updating todo: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/todos/<int:todo_id>', methods=['DELETE'])
def delete_todo(todo_id):
    """Delete a todo"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('DELETE FROM todos WHERE id = %s RETURNING id', (todo_id,))
        row = cur.fetchone()
        if not row:
            return jsonify({'error': 'Todo not found'}), 404
        
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({'message': 'Todo deleted', 'id': todo_id}), 200
    except Exception as e:
        logger.error(f"Error deleting todo: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Initialize database on startup
    try:
        init_db()
        logger.info(f"Starting Flask app in {ENV} environment, version {VERSION}")
    except Exception as e:
        logger.error(f"Failed to initialize database: {str(e)}")
    
    # Run app
    app.run(host='0.0.0.0', port=5000, debug=(ENV == 'dev'))
