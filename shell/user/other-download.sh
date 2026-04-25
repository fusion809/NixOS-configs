#!/usr/bin/env bash
yt-dlp --extractor-args "generic:impersonate" "$1"
# Capture all filenames (output might be multi-line for playlists/parts)
files_list=$(yt-dlp --print filename "$1")

# Convert newline-separated string to array
mapfile -t files <<< "$files_list"

if [ ${#files[@]} -gt 1 ]; then
    echo "Multiple files detected. Merging..."
    
    # Create ffmpeg concat list
    concat_list="concat_files.txt"
    > "$concat_list"
    for f in "${files[@]}"; do
        # Escape single quotes for ffmpeg concat demuxer
        safe_f=$(echo "$f" | sed "s/'/'\\\\''/g")
        echo "file '$safe_f'" >> "$concat_list"
    done
    
    # Define merged filename
    merged_name="merged_output.mp4"
    
    # Merge
    ffmpeg -f concat -safe 0 -i "$concat_list" -c copy -y "$merged_name"
    
    # Cleanup parts and list
    rm "$concat_list"
    rm "${files[@]}"
    
    dest="$merged_name"
    # Use the first file to determine the final name basis
    name_basis="${files[0]}"
else
    dest="${files[0]}"
    name_basis="${files[0]}"
fi

echo "dest=$dest"
# destShort is unused in original script, but we keep it or equivalent logic for the mv? 
# The original script used: mv "$dest" "${dest/\[*\].mp4/} ($duration).mp4"
# We should apply that logic to 'name_basis' for the target name.

duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -sexagesimal "$dest" | sed 's/\..*//' | awk -F: '{ if ($1 == 0) print $2":"$3; else print $0 }')

# Target name logic: remove [id].mp4 from the basis name
target_name="${name_basis/\[*\].mp4/}"

# Also remove sequence numbers like " (1)" that yt-dlp might append for playlist items
# This regex removes optional space + " (N)" where N is any number, typically at the end of the stem, and then trims trailing spaces
target_name=$(echo "$target_name" | sed -r 's/ +(\([0-9]+\))?$//')

# Ensure we don't end up with an empty name or weird state
if [[ -z "$target_name" || "$target_name" == "$name_basis" ]]; then
     # Fallback if substitution failed (e.g. pattern didn't match), remove extension
     target_name="${name_basis%.*}"
     # Attempt to strip sequence number from fallback as well
     target_name=$(echo "$target_name" | sed -r 's/ +(\([0-9]+\))?$//')
fi

# Only append duration if it's not already in the target_name (checking for MM:SS or HH:MM:SS, with : or -)
if [[ ! "$target_name" =~ \([0-9]{1,2}[:\-][0-9]{1,2}([:\-][0-9]{1,2})?\) ]]; then
    mv "$dest" "$target_name ($duration).mp4"
else
    # If duration already exists, just ensure extension is correct if we merged
    mv "$dest" "${target_name}.mp4"
fi