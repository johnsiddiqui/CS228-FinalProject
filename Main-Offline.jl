# John Siddiqui
# Main-Offline

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
Pkg.add("LinearAlgebra")
Pkg.add("JLD2")

include("DataEval_Functions.jl")
include("QLearning_Functions.jl")

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
k = 15  # Number of clusters/state space
result = kmeans(normalized_userGenreMatrix', k)

# Cluster Preferences
cluster_preferences = average_genre_preferences(normalized_userGenreMatrix, result.assignments, k, genresListed)

# Label Clusters
threshold = 0.05
cluster_labels = define_cluster_by_weight(cluster_preferences, genresListed, threshold)
userAssignments = result.assignments
clusterCentroids = result.centers'

## Offline Learning
learningDataPercent = 0.6
numLearningUsers = Int(round(learningDataPercent*numberUsers))
learningData = ratings[ratings.userId .< numLearningUsers+1,:]
testData = ratings[ratings.userId .> numLearningUsers,:]

# Initialize Q
Q = zeros(k, final_num_unique_combinations)

# Initialize User States 
UserState = zeros(numLearningUsers,length(genresListed))
UserStateInteger = zeros(Int,numLearningUsers,1)

for u in 1:numLearningUsers
    randInteger = rand(1:k)
    UserStateInteger[u] = Int(randInteger)
end

# Define hyperparameters
alpha = 0.5                    # Learning rate
alpha_min = 0.05               # Min Learning Rate
alpha_decay = 0.95             # Decay rate of alpha
num_episodes = 2              # Number of episodes
gamma = 0.9

# Learn
using LinearAlgebra
Q = q_learning(Q,learningData,UserStateInteger,UserState,clusterCentroids,reduced_sorted_movieDict,genresListed,final_unique_combinations,num_episodes,gamma,alpha)


# Predict Rating 
testUser = 600
ratingsUser = ratings[ratings.userId .== testUser, :]
numRatingsUser = size(ratingsUser,1)
for r in 1:numRatingsUser
    # initialize
    if r == 1
        userCluster = rand(1:k)
        userPreferences = zeros(1,length(genresListed))
    end
    # sampled data
    movieI = ratingsUser.movieId[r]
    genresI = reduced_sorted_movieDict[movieI].genres
    nameI = reduced_sorted_movieDict[movieI].name
    actionIndex = findfirst(x -> x == genresI, final_unique_combinations)
    # given current state, predict rating given sampled movie
    expectedReturn = Q[userCluster,actionIndex]
    predictedRating = expectedReturn
    actualRating = ratingsUser.rating[r]
    println("ID: $testUser; Movie: $nameI")
    println("Predicted Rating: $predictedRating; Actual Rating: $actualRating")

    # update state
    updatedPreferences = update_user_preferences(userPreferences,genresI,genresListed)
    userPreferences = updatedPreferences
    userCluster = assign_cluster(updatedPreferences, clusterCentroids)
end
max_q = maximum(Q)
min_q = minimum(Q)
#normQ = 2.0 + 3.0 * (predicted_rating - min_q) / (max_q - min_q)















