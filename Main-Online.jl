# John Siddiqui
# Main-Online

using Pkg
Pkg.add("CSV")
Pkg.add("JLD2")
Pkg.add("Statistics")
include("QLearning_Functions.jl")

# Load offline variables
using JLD2, Statistics
@JLD2.load "CS228/variablesLearning-1000-2-2-hybrid-nWeighted.jld2" ratings meanRating testData clusterCentroids k reduced_sorted_movieDict genresListed final_unique_combinations Q UserDemographics class_counts feature_counts num_features feature_levels


# Predict Rating
userIdMin = minimum(testData.userId)
userIdMax = maximum(testData.userId)
numTestUsers = userIdMax-userIdMin+1
maeMatrix = zeros(numTestUsers,3)
maxO = 200 # less than 50 after 197
maeLearn = fill(NaN, numTestUsers, maxO)
maeBaseline = fill(NaN, numTestUsers, maxO)

for testUser in userIdMin:userIdMax
    ratingsUser = ratings[ratings.userId .== testUser, :]
    numRatingsUser = size(ratingsUser,1)
    ratingsMatrix = zeros(numRatingsUser,3)

    for r in 1:numRatingsUser
        # initialize
        if r == 1
            ageI = categorical([string(UserDemographics.age_group[testUser])];levels=levels(UserDemographics.age_group))
            genderI = categorical([string(UserDemographics.gender[testUser])];levels=levels(UserDemographics.gender))
            age_code = levelcode(ageI[1])
            gender_code = levelcode(genderI[1])
            dataI = [age_code,gender_code]
            userCluster = predict_naive_bayes(dataI, class_counts, feature_counts, num_features, feature_levels)
            userPreferences = clusterCentroids[userCluster,:]
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
        randRating = rand(1:5)
        ratingsMatrix[r,1] = actualRating
        ratingsMatrix[r,2] = predictedRating
        ratingsMatrix[r,3] = randRating

        # metrics as a function of observation 
        if r <= maxO && r <= numRatingsUser # every user in dataset has at least 10 observations
            maeLearn[testUser - userIdMin + 1,r] = round(calculate_mae(predictedRating, actualRating),digits=2)
            maeBaseline[testUser - userIdMin + 1,r] = round(calculate_mae(randRating, actualRating),digits=2)
        end
    end

    # Evaluate Performance
    maeModel = round(calculate_mae(ratingsMatrix[:,2], ratingsMatrix[:,1]),digits=2)
    maeRandom = round(calculate_mae(ratingsMatrix[:,3], ratingsMatrix[:,1]),digits=2)
    #println("MAE Model: $maeModel; MAE Baseline: $maeRandom")
    maeMatrix[testUser - userIdMin + 1,1] = testUser 
    maeMatrix[testUser - userIdMin + 1,2] = maeModel 
    maeMatrix[testUser - userIdMin + 1,3] = maeRandom
end

# Evaluate
maeMatrixbyObservations = zeros(maxO,4)
for o in 1:maxO
    filtered_Model = filter(x -> !isnan(x), maeLearn[:,o])
    meanMAEModel = round(mean(filtered_Model),digits=2)
    count_non_nan = sum(!isnan(x) for x in maeLearn[:,o])
    filtered_Baseline = filter(x -> !isnan(x), maeBaseline)
    meanMAEBaseline = round(mean(filtered_Baseline),digits=2)
    maeMatrixbyObservations[o,1] = o 
    maeMatrixbyObservations[o,2] = meanMAEModel
    maeMatrixbyObservations[o,3] = meanMAEBaseline
    maeMatrixbyObservations[o,4] = count_non_nan
    println("Observation: $o; MAE Model: $meanMAEModel; MAE Baseline: $meanMAEBaseline; # Users: $count_non_nan")
end

# Save metrics
using CSV
#column_names = [:UserId, :Model, :Baseline]
maeMatrixbyObservations[maeMatrixbyObservations .== 0] .= NaN
column_names = [:Observation, :Model, :Baseline, :NumUsers]
df = DataFrame(maeMatrixbyObservations, column_names)
CSV.write("CS228/metrics-1000-2-2-other-nhybrid-nWeighted.csv", df)

