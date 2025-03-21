#!/bin/bash

# Directory containing the JSON files
DIRECTORY="src/main/api/" # Update with the actual path

# Required operations
OPERATIONS=("create" "update" "delete" "retrieve" "patch")

# Entities to exclude from validation
EXCLUDE_ENTITIES=("specialEntity1" "specialEntity2") # Add any entities to exclude

# Function to check if an entity is in the exclude list
is_excluded() {
    local entity="$1"
    for excluded in "${EXCLUDE_ENTITIES[@]}"; do
        if [[ "$entity" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

# Declare an associative array to track entities and their operations
entity_files=()

# Process each JSON file in the directory
for file in "$DIRECTORY"/create*.json; do
    [[ -e "$file" ]] || continue # Skip if no JSON files are found

    # Extract operation and entity name
    filename=$(basename "$file" .json)
    #echo $filename
   
    entity=$(echo "$filename" | sed -E "s/^create//" | sed 's/.json$//')
    #echo $entity

    # Skip if the entity is in the exclude list
    if is_excluded "$entity"; then
        continue
    fi

    # Track operations for each entity
    entity_files+=("$entity")
    #echo ${entity_files[@]}
done

# Check if each entity has all required operations
missing_count=0

for entity in "${entity_files[@]}"; do
    missing_operations=()
    
    for op in "${OPERATIONS[@]}"; do
        if [[ ! -e "$DIRECTORY"/${op}${entity}.json ]]; then
            #echo "testing $DIRECTORY/${op}${entity}.json"
            missing_operations+=("$op")
        fi
    done

    if [[ ${#missing_operations[@]} -gt 0 ]]; then
        echo "Entity '$entity' is missing operations: ${missing_operations[*]}"
        ((missing_count++))
    fi
done

# Exit with the number of entities missing operations
exit $missing_count


