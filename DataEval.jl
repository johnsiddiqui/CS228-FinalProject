# John Siddiqui
# Data Processing

## Packages
using Pkg
Pkg.add("CSV")
Pkg.add("Printf")
Pkg.add("DataFrames")
Pkg.add("StatsBase")

include("DataEval_Functions.jl")

using CSV
using DataFrames

# Load ratings and movies data
ratings = CSV.File("CS228/Data/ml-100k/u.data", header = false) |> DataFrame
rename!(ratings, [:userId,:movieId,:rating,:timestamp])

movies = CSV.File("CS228/Data/ml-100k/u.item", header = false) |> DataFrame
rename!(movies, [:movieId,:movieTitle,:releaseDate,:unk,:url,:unknown,:action,:adventure,:animation,:childrens,:comedy,:crime,:documentary,
:drama,:fantasy,:filmNoir,:horror,:musical,:mystery,:romance,:sciFi,:thriller,:war,:western])

users = CSV.File("CS228/Data/ml-100k/u.user", header = false) |> DataFrame #user id | age | gender | occupation | zip code
rename!(users, [:userId,:age,:gender,:occupation,:zipCode])

# Other
genres = CSV.File("CS228/Data/ml-100k/u.genre", header = false) |> DataFrame #genre ids
occupations = CSV.File("CS228/Data/ml-100k/u.occupation", header = false) |> DataFrame #occupations listed

# Movie Struct
struct movieFile
    id
    name
    genres
    releaseYear
end

movieDict = Dict()
numberOfMovies = size(movies,1)
genresBegin = 6; genresEnd = 24

for m in 1:numberOfMovies
    row = movies[m,:]
    name = row[2]
    truefalseGenres = row[genresBegin:genresEnd]
    trueGenres = names(truefalseGenres)[collect(truefalseGenres) .== 1]
    year = row[3]
    if ismissing(year)
        year = NaN
    else
        year = parse(Int,year[end-3:end])
    end
    movieDict[m] = movieFile(m,name,trueGenres,year)
end

# Extract genre lists while preserving the original order
genre_combinations = [movieDict[i].genres for i in 1:numberOfMovies]  # Get all genre lists

# Use `unique` to eliminate duplicates while preserving the first occurrence order
unique_combinations = unique(genre_combinations)

# Number of unique combinations
num_unique_combinations = length(unique_combinations)

numMoviesofType = zeros(num_unique_combinations,1)

for n in 1:num_unique_combinations
    for m in 1:numberOfMovies
        if unique_combinations[n] == movieDict[m].genres
            numMoviesofType[n] += 1
        end
    end
end

# Evaluate Genre Frequency
all_genres = reduce(vcat, [movie.genres for movie in values(movieDict)])
using StatsBase
genre_frequency = countmap(all_genres)

# Sort by Frequency
sorted_movieDict = sort_movie_genres(movieDict, genre_frequency)

# Reduce Genre Assignment to <= 2 with Priority given to the Least Frequent/Most Unique Genres
n_genres = 2
reduced_sorted_movieDict = retain_n_genres(sorted_movieDict,n_genres)
reduced_genre_combination_counts = countmap([Tuple(sort(movie.genres)) for movie in values(reduced_sorted_movieDict)])

# Reassign all Underobserved Combinations to a Singular Genre where the Singular Genre is the Least Frequent/Most Unique Genre
min_observations = 5
final_movieDict = reassign_underobserved_genres(reduced_sorted_movieDict, min_observations)
final_genre_combination_counts = countmap([Tuple(sort(movie.genres)) for movie in values(final_movieDict)])

# Print Result 
open("final_movies_genres.txt", "w") do file
    for (id, movie) in final_movieDict
        println(file,"$(movie.name);$(join(movie.genres,";"))")
    end
end

open("final_genre_combination_counts.txt", "w") do file
    for (combination, count) in final_genre_combination_counts
        # Convert the combination tuple to a string
        combination_str = join(combination, "|")
        # Write the combination and count to the file
        println(file, "$combination_str: $count")
    end
end






