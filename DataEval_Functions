# John Siddiqui
# Data Processing Functions

# Function to sort genres based on frequency
function sort_movie_genres(movieDict, genre_frequency)
    # Create a new dictionary with sorted genres
    sorted_movieDict = Dict()

    for (id, movie) in movieDict
        # Sort genres by their frequency (ascending) and use alphabetical order as a tiebreaker
        #sorted_genres = sort(movie.genres, by=x -> (-genre_frequency[x], x))
        sorted_genres = sort(movie.genres, by=x -> (genre_frequency[x], x))
        
        # Create a new movieFile with sorted genres
        sorted_movieDict[id] = movieFile(movie.id, movie.name, sorted_genres, movie.releaseYear)
    end

    return sorted_movieDict
end

# Function to retain only n-genres for each movie
function retain_n_genres(movieDict, max_genres)
    # Iterate over each movie and update genres
    for (id, movie) in movieDict
        # Keep only n-genres
        updated_genres = movie.genres[1:min(max_genres, length(movie.genres))]
        # Update the movie entry in the dictionary
        movieDict[id] = movieFile(movie.id, movie.name, updated_genres, movie.releaseYear)
    end
    return movieDict
end

# Function to reassign genres for underobserved combinations
function reassign_underobserved_genres(movieDict, min_observations)
    # Step 1: Count genre combination frequencies
    genre_combination_counts = countmap([Tuple(sort(movie.genres)) for movie in values(movieDict)])
    
    # Step 2: Count individual genre frequencies
    all_genres = reduce(vcat, [movie.genres for movie in values(movieDict)])
    individual_genre_counts = countmap(all_genres)

    # Step 3: Reassign genres for underobserved combinations
    for (id, movie) in movieDict
        # Get the current genre combination
        current_combination = Tuple(sort(movie.genres))
        
        # Check if the combination is underobserved
        if genre_combination_counts[current_combination] < min_observations
            # Reassign to the least common individual genre
            least_common_genre = argmin(x -> individual_genre_counts[x], movie.genres)
            movieDict[id] = movieFile(movie.id, movie.name, [least_common_genre], movie.releaseYear)
        end
    end
    return movieDict
end