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
sorted_genres = sort(collect(genre_frequency), by=x -> -x[2])

# Sort by Frequency
sorted_movieDict = sort_movie_genres(movieDict, genre_frequency)

# Retain only the top genres
n_genres = 3
reduced_sorted_movieDict = retain_top_genres(sorted_movieDict,n_genres)

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

open("reduced3_movieTypes.txt", "w") do file
    for n in 1:reduced_num_unique_combinations  # Loop over each row
        type = join(reduced_unique_combinations[n],"|")
        number = reduced_numMoviesofType[n]
        println(file,"$type: $number")
    end
end




