from flask import current_app as app, request, jsonify
from . import db
from .models import Movie

# 1. GET /api/movies & /api/movies/ (Get all or filter by ?title=[name])
# 2. POST /api/movies & /api/movies/ (Create a new movie)
# 3. DELETE /api/movies & /api/movies/ (Delete all movies in the database)
@app.route(
    '/api/movies',
    methods=['GET', 'POST', 'DELETE'],
    strict_slashes=False
)
def handle_movies():
    if request.method == 'GET':
        title_query = request.args.get('title')
        if title_query:
            movies = Movie.query.filter(Movie.title.ilike(f"%{title_query}%")).all()
        else:
            movies = Movie.query.all()
        return jsonify([movie.to_dict() for movie in movies]), 200

    elif request.method == 'POST':
        data = request.get_json()
        if not data or 'title' not in data:
            return jsonify({"error": "Movie title is required"}), 400
        
        new_movie = Movie(
            title=data['title'],
            description=data.get('description', '')
        )
        db.session.add(new_movie)
        db.session.commit()
        return jsonify(new_movie.to_dict()), 201

    elif request.method == 'DELETE':
        try:
            num_deleted = db.session.query(Movie).delete()
            db.session.commit()
            return jsonify({"message": f"Successfully deleted all {num_deleted} movies."}), 200
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 500


# 4. GET /api/movies/<id> & /api/movies/<id>/ (Retrieve a single movie by ID)
# 5. PUT /api/movies/<id> & /api/movies/<id>/ (Update a single movie by ID)
# 6. DELETE /api/movies/<id> & /api/movies/<id>/ (Delete a single movie by ID)
@app.route(
    '/api/movies/<int:movie_id>',
    methods=['GET', 'PUT', 'DELETE'],
    strict_slashes=False
)
def handle_movie_by_id(movie_id):
    movie = db.session.get(Movie, movie_id)
    if not movie:
        return jsonify({"error": "Movie not found"}), 404

    if request.method == 'GET':
        return jsonify(movie.to_dict()), 200

    elif request.method == 'PUT':
        data = request.get_json()
        if not data:
            return jsonify({"error": "Invalid payload"}), 400

        if 'title' in data:
            movie.title = data['title']
        if 'description' in data:
            movie.description = data['description']

        db.session.commit()
        return jsonify(movie.to_dict()), 200

    elif request.method == 'DELETE':
        db.session.delete(movie)
        db.session.commit()
        return jsonify({"message": f"Movie with ID {movie_id} deleted successfully."}), 200
