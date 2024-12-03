# John Siddiqui
# Main-Online

using Pkg
Pkg.add("CSV")
Pkg.add("JLD2")
include("QLearning_Functions.jl")

# Load offline variables
using JLD2
@load "CS228/variablesLearning.jld2" ratings meanRating testData clusterCentroids k reduced_sorted_movieDict genresListed final_unique_combinations Q

# Predict Rating
userIdMin = minimum(testData.userId)
userIdMax = maximum(testData.userId)
numTestUsers = userIdMax-userIdMin+1
maeMatrix = zeros(numTestUsers,3)

for testUser in userIdMin:userIdMax
    ratingsUser = ratings[ratings.userId .== testUser, :]
    numRatingsUser = size(ratingsUser,1)
    ratingsMatrix = zeros(numRatingsUser,3)

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
        Qi = Q[userCluster,actionIndex]
        predictedRating = ratingPredict(meanRating,Q,Qi)
        actualRating = ratingsUser.rating[r]
        #println("ID: $testUser; Movie: $nameI")
        #println("Predicted Rating: $predictedRating; Actual Rating: $actualRating")

        # update state
        updatedPreferences = update_user_preferences(userPreferences,genresI,genresListed)
        userPreferences = updatedPreferences
        userCluster = assign_cluster(updatedPreferences, clusterCentroids)

        # metrics
        ratingsMatrix[r,1] = actualRating
        ratingsMatrix[r,2] = predictedRating
        ratingsMatrix[r,3] = rand(1:5)
    end

    # Evaluate Performance
    maeModel = round(calculate_mae(ratingsMatrix[:,2], ratingsMatrix[:,1]),digits=2)
    maeRandom = round(calculate_mae(ratingsMatrix[:,3], ratingsMatrix[:,1]),digits=2)
    println("MAE Model: $maeModel; MAE Baseline: $maeRandom")
    maeMatrix[testUser - userIdMin + 1,1] = testUser 
    maeMatrix[testUser - userIdMin + 1,2] = maeModel 
    maeMatrix[testUser - userIdMin + 1,3] = maeRandom
end

# Save metrics
using CSV
column_names = [:UserId, :Model, :Baseline]
df = DataFrame(maeMatrix, column_names)
CSV.write("CS228/metrics.csv", df)