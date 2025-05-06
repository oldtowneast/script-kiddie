#!/bin/bash

# Array of extensions to consider (e.g., jpg, png)
extensions=("jpg" "png")

# Construct the find command with the allowed extensions
find_cmd="find . -type f"
for ext in "${extensions[@]}"; do
    find_cmd="$find_cmd \( -iname '*.$ext' \) -or"
done
# Remove the trailing '-or'
find_cmd=${find_cmd% -or}

# Execute the constructed find command and rename found files
eval "$find_cmd" | while read -r file; do
    random_filename=$(openssl rand -hex 9)."${file##*.}"
    mv "$file" "${file%/*}/$random_filename"
done
