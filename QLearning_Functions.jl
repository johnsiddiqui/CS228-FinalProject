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
            println("userI: $userI; state: $state; action: $action; reward: $reward; next state: $next_state")

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
