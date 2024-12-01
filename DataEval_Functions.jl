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

function average_genre_preferences(user_genre_matrix, assignments, k, genres)
    cluster_preferences = Dict()
    for cluster_id in 1:k
        # Get rows for users in this cluster
        user_indices = findall(x -> x == cluster_id, assignments)
        cluster_data = user_genre_matrix[user_indices, :]
        
        # Calculate average preferences for this cluster
        avg_preferences = mean(cluster_data, dims=1)
        cluster_preferences[cluster_id] = avg_preferences
    end
    return cluster_preferences
end


function save_cluster_plots(cluster_preferences, genres, folder_path="cluster_plots")
    # Ensure the folder exists
    if !isdir(folder_path)
        mkdir(folder_path)
    end
    
    # Iterate over each cluster and save the plot
    for (cluster_id, preferences) in cluster_preferences
        # Generate the bar plot
        bar(genres, preferences[:], label="Genres", color=:skyblue, legend=:topright, 
           xticks=(1:length(genres), genres), rotation=45, bar_width=0.5)
        
        # Save the plot
        file_name = joinpath(folder_path, "cluster_$cluster_id.png")
        savefig(file_name)
        println("Saved plot for Cluster $cluster_id at $file_name")
    end
end

function label_clusters(cluster_preferences, genres, top_n)
    cluster_labels = Dict()
    for (cluster_id, preferences) in cluster_preferences
        # Sort genres by preference in descending order
        sorted_indices = sortperm(preferences[:], rev=true)
        
        # Get the top `top_n` genres for this cluster
        dominant_genres = genres[sorted_indices[1:top_n]]
        cluster_labels[cluster_id] = dominant_genres
    end
    return cluster_labels
end

function define_cluster_by_threshold(cluster_preferences, genres, threshold)
    cluster_labels = Dict()
    
    for (cluster_id, preferences) in cluster_preferences
        # Flatten preferences to ensure 1D array
        preferences = vec(preferences)
        
        # Sort genres by preference (descending)
        sorted_indices = sortperm(preferences, rev=true)
        sorted_preferences = preferences[sorted_indices]
        sorted_genres = genres[sorted_indices]
        
        # Compute cumulative sum
        cumulative_sum = cumsum(sorted_preferences)
        total_sum = sum(preferences)
        
        # Find genres contributing to the threshold
        cutoff_index = findfirst(x -> x / total_sum >= threshold, cumulative_sum)
        selected_genres = sorted_genres[1:cutoff_index]
        
        # Label the cluster with the selected genres
        cluster_labels[cluster_id] = selected_genres
    end
    
    return cluster_labels
end

function define_cluster_by_weight(cluster_preferences, genres, threshold)
    cluster_labels = Dict()
    
    for (cluster_id, preferences) in cluster_preferences
        # Flatten preferences to ensure 1D array
        preferences = vec(preferences)
        
        # Compute relative weights
        total_sum = sum(preferences)
        relative_weights = preferences ./ total_sum  # Normalize to percentages
        
        # Filter genres exceeding the threshold
        selected_indices = findall(x -> x >= threshold, relative_weights)
        selected_genres = genres[selected_indices]
        
        # Label the cluster with the selected genres
        cluster_labels[cluster_id] = selected_genres
    end
    
    return cluster_labels
end

function define_cluster_without_drama_comedy(cluster_preferences, genres, excluded_genres, threshold)
    # Find indices of excluded genres
    excluded_indices = findall(x -> x in excluded_genres, genres)

    cluster_labels = Dict()
    for (cluster_id, preferences) in cluster_preferences
        # Flatten preferences to ensure 1D array
        preferences = vec(preferences)
        
        # Exclude Drama and Comedy
        filtered_preferences = preferences
        filtered_preferences[excluded_indices] .= 0  # Set excluded genres to 0

        # Re-normalize preferences
        total_sum = sum(filtered_preferences)
        normalized_preferences = filtered_preferences ./ total_sum

        # Filter genres exceeding the threshold
        selected_indices = findall(x -> x >= threshold, normalized_preferences)
        selected_genres = genres[selected_indices]
        
        # Label the cluster with the selected genres
        cluster_labels[cluster_id] = selected_genres
    end
    
    return cluster_labels
end

function define_cluster_with_marginalized_genres(cluster_preferences, genres, marginalize_genres, scale, threshold)
    # Find indices of genres to marginalize
    marginalize_indices = findall(x -> x in marginalize_genres, genres)

    cluster_labels = Dict()
    for (cluster_id, preferences) in cluster_preferences
        # Flatten preferences to ensure 1D array
        preferences = vec(preferences)
        
        # Scale contributions of marginalized genres
        scaled_preferences = copy(preferences)
        scaled_preferences[marginalize_indices] .= scaled_preferences[marginalize_indices] .* scale

        # Re-normalize preferences
        total_sum = sum(scaled_preferences)
        normalized_preferences = scaled_preferences ./ total_sum

        # Filter genres exceeding the threshold
        selected_indices = findall(x -> x >= threshold, normalized_preferences)
        selected_genres = genres[selected_indices]
        
        # Label the cluster with the selected genres
        cluster_labels[cluster_id] = selected_genres
    end
    
    return cluster_labels
end

function define_cluster_with_two_marginalized_groups(cluster_preferences,genres, group_1_genres, group_1_scale, group_2_genres, group_2_scale, threshold)
    # Find indices for both groups of marginalized genres
    group_1_indices = findall(x -> x in group_1_genres, genres)
    group_2_indices = findall(x -> x in group_2_genres, genres)

    cluster_labels = Dict()
    for (cluster_id, preferences) in cluster_preferences
        # Flatten preferences to ensure 1D array
        preferences = vec(preferences)
        
        # Apply scaling to the two groups
        scaled_preferences = copy(preferences)
        scaled_preferences[group_1_indices] .= scaled_preferences[group_1_indices] .* group_1_scale
        scaled_preferences[group_2_indices] .= scaled_preferences[group_2_indices] .* group_2_scale

        # Re-normalize preferences
        total_sum = sum(scaled_preferences)
        normalized_preferences = scaled_preferences ./ total_sum

        # Filter genres exceeding the threshold
        selected_indices = findall(x -> x >= threshold, normalized_preferences)
        selected_genres = genres[selected_indices]
        
        # Label the cluster with the selected genres
        cluster_labels[cluster_id] = selected_genres
    end
    
    return cluster_labels
end

