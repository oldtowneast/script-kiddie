#!/bin/bash

if [ -z "$1" ]; then
    echo "Please provide a search term"
    exit 1
fi

# Default URLs
urls=(
    "https://www.sendiks.com/shop#!/?q=%s"
    "https://www.metromarket.net/search?query=%s"
)

# Check for flags
while getopts "sm" opt; do
    case $opt in
        s) urls=("https://www.sendiks.com/shop#!/?q=%s");;
        m) urls=("https://www.metromarket.net/search?query=%s");;
        ?) echo "Usage: $0 [-s|m] <search term>"; exit 1;;
    esac
done

# Shift past the options to get the search term
shift $((OPTIND-1))

if [ -z "$1" ]; then
    echo "Please provide a search term after the flag"
    exit 1
fi

# URL-encode the query using Python
query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$1'))")

# Define the browser command
browser="brave-browser"

# Open the URLs with the encoded query
for url in "${urls[@]}"; do
    final_url=$(printf "$url" "$query")
    $browser "$final_url" &
done