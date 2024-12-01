# John Siddiqui
# Learning Functions

function assign_new_user(user_preferences, centroids)
    similarities = [dot(user_preferences, centroid) / (norm(user_preferences) * norm(centroid)) for centroid in centroids]
    return argmax(similarities)  # Returns the cluster ID
end