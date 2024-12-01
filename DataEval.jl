# John Siddiqui
# Data Processing

## Packages
using Pkg
Pkg.add("CSV")
Pkg.add("Printf")
Pkg.add("DataFrames")
Pkg.add("StatsBase")
Pkg.add("Clustering")
Pkg.add("Statistics")
Pkg.add("Plots")
Pkg.add("FileIO")

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

# Extract Final Genre List in Vector Form
final_genre_combinations = [final_movieDict[i].genres for i in 1:numberOfMovies]
final_unique_combinations = unique(final_genre_combinations) #action space
final_num_unique_combinations = length(final_unique_combinations) #size of action space

# Define User Genre Matrix
numberRatings = size(ratings,1)
numberUsers = size(users,1)
genresListed = unique(all_genres)
numberGenres = length(genresListed)
userGenreMatrix = zeros(numberUsers,numberGenres)
for r in 1:numberRatings
    userI = ratings.userId[r]
    movieI = ratings.movieId[r]
    for u in 1:numberUsers
        if u == userI
            for g in 1:numberGenres
                genreI = genresListed[g]
                if genreI in movieDict[movieI].genres # use og data
                    userGenreMatrix[userI,g] += 1
                end
            end
        end
    end
end

normalized_userGenreMatrix = userGenreMatrix ./ sum(userGenreMatrix, dims=2)

# K-Means Clustering
using Clustering, Statistics, IterTools
k = 8  # Number of clusters
result = kmeans(normalized_userGenreMatrix, k)

# Cluster Preferences
cluster_preferences = average_genre_preferences(normalized_userGenreMatrix, result.assignments, k, genresListed)

# Plot Clusters
#using Plots, FileIO
#save_cluster_plots(cluster_preferences, genresListed) #these plots need to be improved if we want to include in documentation

# Label Clusters
threshold = 0.10
group_1_scale=0.4
group_2_scale=0.8
group_1_genres=["drama", "comedy"]
group_2_genres=["romance", "thriller","action"]
cluster_labels = define_cluster_with_two_marginalized_groups(cluster_preferences, genresListed, group_1_genres, group_1_scale, group_2_genres, group_2_scale, threshold)

# Print cluster labels
for (cluster_id, dominant_genres) in cluster_labels
    println("Cluster $cluster_id: Dominant Genres - ", join(dominant_genres, ", "))
end

# Save cluster labels to a text file
open("cluster_labels.txt", "w") do file
    for (cluster_id, dominant_genres) in cluster_labels
        println(file, "Cluster $cluster_id: Dominant Genres - ", join(dominant_genres, ", "))
    end
end
println("Cluster labels saved to 'cluster_labels.txt'")








