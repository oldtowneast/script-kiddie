#!/bin/bash

# Get all .flac files and store them in an array
files=(*.flac)

# Reverse the order of files
reversed=($(printf "%s\n" "${files[@]}" | tac))

# Counter for new numbering
counter=1

# Loop through the reversed list and rename files
for file in "${reversed[@]}"; do
    # Extract the song title by removing the leading number
    title="${file#*.}"
    
    # Format new filename with leading zero
    new_filename=$(printf "%02d.%s" "$counter" "$title")
    
    # Rename the file
    mv "$file" "$new_filename"
    
    # Increment counter
    ((counter++))
done

echo "Files renamed successfully in reverse order."
