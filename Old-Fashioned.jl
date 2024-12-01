# Evaluate Movie Genres 
open("movie_genres.txt", "w") do file
    for row in 1:size(movies, 1)  # Loop over each row
        nameMovie = movies[row,2]

        # Find column names where value is 1
        truefalseGenres = movies[row,genresBegin:genresEnd]
        trueGenres = names(truefalseGenres)[collect(truefalseGenres) .== 1]
        
        # Write results to the file
        println(file, "$nameMovie, ", join(trueGenres, ", "))
    end
end

open("movieTypes.txt", "w") do file
    for n in 1:num_unique_combinations  # Loop over each row
        type = join(unique_combinations[n],"|")
        number = numMoviesofType[n]
        println(file,"$type: $number")
    end
end

open("movie_genres.txt", "w") do file
    for row in 1:numberOfMovies # Loop over each row
        nameMovie = movies[row,2]

        # Find column names where value is 1
        truefalseGenres = movies[row,genresBegin:genresEnd]
        trueGenres = names(truefalseGenres)[collect(truefalseGenres) .== 1]
        
        # Write results to the file
        println(file, "$nameMovie; ", join(trueGenres, "; "))
    end
end

open("movies_sorted_genres.txt", "w") do file
    for (id, movie) in sorted_movieDict
        println(file,"$(movie.name);$(join(movie.genres,";"))")
    end
end

open("reduced_movieTypes.txt", "w") do file
    for n in 1:reduced_num_unique_combinations  # Loop over each row
        type = join(reduced_unique_combinations[n],"|")
        number = reduced_numMoviesofType[n]
        println(file,"$type: $number")
    end
end

# Extract genre lists while preserving the original order
reduced_genre_combinations = [reduced_sorted_movieDict[i].genres for i in 1:numberOfMovies]  # Get all genre lists

# Use `unique` to eliminate duplicates while preserving the first occurrence order
reduced_unique_combinations = unique(reduced_genre_combinations)

# Number of unique combinations
reduced_num_unique_combinations = length(reduced_unique_combinations)

reduced_numMoviesofType = zeros(reduced_num_unique_combinations,1)

for n in 1:reduced_num_unique_combinations
    for m in 1:numberOfMovies
        if reduced_unique_combinations[n] == reduced_sorted_movieDict[m].genres
            reduced_numMoviesofType[n] += 1
        end
    end
end

