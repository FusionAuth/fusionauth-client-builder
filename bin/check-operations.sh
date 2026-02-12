#!/bin/bash

#
# Copyright (c) 2026, FusionAuth, All Rights Reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#
# Directory containing the JSON files
DIRECTORY="src/main/api/" 

# Required operations
OPERATIONS=("create" "update" "delete" "retrieve" "patch")

# Entities/ops to exclude from validation
EXCLUDE_ENTITIES_OPS=("UserConsent-delete" "ApplicationRole-retrieve" "Family-delete" "Family-patch" "Family-retrieve" "EntityTypePermission-retrieve" "ApplicationRole-retrieve" "GroupMembers-retrieve" "GroupMembers-patch" "UserLink-patch" "UserLink-update" "AuditLog-delete" "AuditLog-patch" "AuditLog-update" "TenantManagerIdentityProviderTypeConfiguration-retrieve")


# Function to check if an entity is in the exclude list
is_excluded() {
    local entity="$1"
    local op="$2"
    for excluded in "${EXCLUDE_ENTITIES_OPS[@]}"; do
        if [[ "${entity}-${op}" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

# Declare an array to track entities and their operations
entity_files=()

# Process each JSON file in the directory
for file in "$DIRECTORY"/create*.json; do
    [[ -e "$file" ]] || continue # Skip if no JSON files are found

    # Extract operation and entity name
    filename=$(basename "$file" .json)
   
    entity=$(echo "$filename" | sed -E "s/^create//" | sed 's/.json$//')

    # Track operations for each entity
    entity_files+=("$entity")
done

# Check if each entity has all required operations
missing_count=0

for entity in "${entity_files[@]}"; do
    missing_operations=()
    
    for op in "${OPERATIONS[@]}"; do

        # Skip if the entity is in the exclude list
        if is_excluded "$entity" "$op"; then
           continue
        fi

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


