# John Siddiqui
# Data Processing Functions

# Function to sort genres based on frequency
function sort_movie_genres(movieDict, genre_frequency)
    # Create a new dictionary with sorted genres
    sorted_movieDict = Dict()

    for (id, movie) in movieDict
        # Sort genres by their frequency (descending) and use alphabetical order as a tiebreaker
        sorted_genres = sort(movie.genres, by=x -> (-genre_frequency[x], x))
        
        # Create a new movieFile with sorted genres
        sorted_movieDict[id] = movieFile(movie.id, movie.name, sorted_genres, movie.releaseYear)
    end

    return sorted_movieDict
end

# Function to retain only the top genres for each movie
function retain_top_genres(movieDict, max_genres=2)
    # Iterate over each movie and update genres
    for (id, movie) in movieDict
        # Keep only the top `max_genres` genres
        updated_genres = movie.genres[1:min(max_genres, length(movie.genres))]
        # Update the movie entry in the dictionary
        movieDict[id] = movieFile(movie.id, movie.name, updated_genres, movie.releaseYear)
    end
    return movieDict
end