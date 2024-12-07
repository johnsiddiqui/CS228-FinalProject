# John Siddiqui
# Learning Functions

# Compute cosine similarity
function cosine_similarity(v1, v2)
    return dot(v1, v2) / (norm(v1) * norm(v2))
end

# Assign user to the best cluster
function assign_cluster(user_preferences, centroids)
    numClusters = size(centroids,1)
    similarities = [cosine_similarity(user_preferences, centroids[i, :]) for i in 1:numClusters]
    indexBestCluster = argmax(similarities)
    return indexBestCluster  # Returns the index of the best cluster
end

# Update User Preferences
function update_user_preferences(user_preferences, movie_genres, genre_list)
    updated_preferences = copy(user_preferences)
    for genre in movie_genres
        index = findfirst(x -> x == genre, genre_list)
        if index !== nothing
            updated_preferences[index] += 1  # Increment genre count
        end
    end
    # Normalize preferences to make them comparable
    return updated_preferences ./ sum(updated_preferences)
end

# Q-learning
function q_learning(Q,learningData,UserStateInteger,UserState,clusterCentroids,movieDict,genres,genre_combinations,num_episodes,gamma,alpha)
    n = size(learningData,1)
    num_actions = length(final_unique_combinations)
    for episode in 1:num_episodes
        for t = 1:n
            userI = learningData.userId[t]
            userPreferences = UserState[userI,:]
            movieI = learningData.movieId[t]
            state = UserStateInteger[userI]
            genresI = movieDict[movieI].genres
            action = findfirst(x -> x == genresI, genre_combinations)
            reward = learningData.rating[t]
            updated_preferences = update_user_preferences(userPreferences,genresI,genres)
            UserState[userI,:] = updated_preferences
            assigned_cluster = assign_cluster(updated_preferences, clusterCentroids)
            next_state = assigned_cluster
            #println("userI: $userI; state: $state; action: $action; reward: $reward; next state: $next_state")

            # Q-learning update
            max_next_q = maximum(Q[next_state, a] for a = 1:num_actions)
            Q[state, action] = Q[state, action] + alpha * (reward + gamma * max_next_q - Q[state, action])
        end
        println("Episode $episode")
    end
    return Q
end

## Predict Rating
function ratingPredict(meanRating,Q,Qi)
    meanQ = mean(Q)
    maxQ = maximum(Q)
    minQ = minimum(filter(x -> x != 0, Q))
    rangeUp = maxQ - meanQ
    rangeDown = meanQ - minQ
    if Qi > meanQ
        delta = (Qi - meanQ)/rangeUp*2
        score = Int(round(meanRating + delta))
    else
        delta = (meanQ - Qi)/rangeDown*2
        score = Int(round(meanRating - delta))
    end
    return score 
end

# Mean Absolute Error
function calculate_mae(predictions, actuals)
    n = length(predictions)
    sum(abs.(predictions .- actuals)) / n
end

# Demographis User Group Assignment
function profileUser(userId,users)
    ageI = users.age[userId]
    genderI = users.gender[userId]
    profileInt = ceil(ageI/10)#i.e., if you are in your 40s, 5 etc.; [1,8] in this dataset
    if genderI == "M"
        return profileInt
    else
        return profileInt+ceil(maximum(users.age)/10)
    end
end

# Compute priors and conditional probabilities
# P(C) = class_counts[c] / N
# P(F_j = f | C) = feature_counts[(j, c, f)] / class_counts[c]
function predict_naive_bayes(x::Vector{Int},class_counts::Vector{Int},feature_counts::Dict{Tuple{Int,Int,Int},Int},num_features::Int,feature_levels::Vector{Int})

    N = sum(class_counts)
    best_class = 0
    best_score = -Inf

    for c in 1:length(class_counts)
        log_prob = log(class_counts[c]) - log(N) # Compute log probability to avoid underflow, log P(C)

        # Multiply by each feature probability
        for j in 1:num_features
            f_val = x[j]
            key = (j, c, f_val)
            count = get(feature_counts, key, 0)
            # Laplace smoothing: P(F_j=f_val | C) = (count + 1) / (class_counts[c] + feature_levels[j])
            num_levels = feature_levels[j]
            log_prob += log(count + 1) - log(class_counts[c] + num_levels)
        end

        # Keep track of the best class
        if log_prob > best_score
            best_score = log_prob
            best_class = c
        end
    end

    return best_class
end

# Silhouette Score 
function silhouetteScore(k,userAssignments,clusterCentroids,normalized_userGenreMatrix)
    scoreMatrix = zeros(k,1)
    numPoints = size(normalized_userGenreMatrix,1)
    distanceCounts = zeros(k,2) #1st column is for sum of distance, 2nd column is for number of points
    for point in 1:numPoints
        pointVector = normalized_userGenreMatrix[point,:]
        pointAssignment = userAssignments[point]
        centroidI = clusterCentroids[pointAssignment,:]
        distance = abs(cosine_similarity(pointVector,centroidI))
        distanceCounts[pointAssignment,1] += distance
        distanceCounts[pointAssignment,2] += 1
    end

    for i in 1:k
        ai = distanceCounts[i,1]/distanceCounts[i,2] #Average distance of point i to all other points in the same cluster (intracluster distance)
        bi = Inf
        for o in 1:k
            if o != i #Minimum average distance of point i to all points in any other cluster (nearest-cluster distance)
                # defined as the distance to the nearest centroid as a centroid is defined as the average location of all the points in a cluster
                bi_candidate = abs(cosine_similarity(clusterCentroids[o,:],clusterCentroids[i,:]))
                if bi_candidate < bi 
                    bi = bi_candidate
                end 
            end 
        end
        scoreMatrix[i] = (bi - ai)/max(ai,bi)
    end
    return scoreMatrix, distanceCounts
end