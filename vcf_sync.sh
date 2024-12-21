#!/bin/bash
#
# VCF File Sync & Lock Script
# Copyright (c) 2024 Kyle Affolder
# Licensed under the MIT License. See LICENSE file in the project root
# for full license information.
#

PROCESS_FILES=0

process_vcf_file() {
  local file="$1"
  
  # Check if file already has the lock emoji
  if ! grep -q " 🔒" "$file"; then
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Process the file
    while IFS= read -r line; do
      if [[ "$line" =~ ^N: ]] && ! [[ "$line" =~ " 🔒" ]]; then
        # Insert lock emoji before first semicolon
        echo "$line" | sed 's/:/: 🔒;/' >> "$temp_file"
      elif [[ "$line" =~ ^REV: ]]; then
        # Replace timestamp with current ISO 8601 date
        echo "REV:$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$temp_file"
      else
        echo "$line" >> "$temp_file"
      fi
    done < "$file"
    
    # Replace original file with processed file
    mv "$temp_file" "$file"
    echo "Processed file: $file"
  fi
}

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source_directory> <destination_directory>"
  exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--process)
      PROCESS_FILES=1
      shift
      ;;
    *)
      ;;
  esac
done

SOURCE_DIR="$1"
DEST_DIR="$2"

# Check if directories exist
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory '$SOURCE_DIR' does not exist"
  exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
  echo "Creating destination directory '$DEST_DIR'"
  mkdir -p "$DEST_DIR"
fi

# Initial copy of all .vcf files
echo "Performing initial copy of .vcf files..."
find "$SOURCE_DIR" -name "*.vcf" -type f -exec bash -c '
  src="$1"
  dest="$2/${1#$3}"
  destdir=$(dirname "$dest")
  mkdir -p "$destdir"
  cp "$src" "$dest"
  process_vcf_file "$dest"
' bash {} "$DEST_DIR" "$SOURCE_DIR" \;

echo "Initial copy complete."

# Process VCF files if requested
if [ "$PROCESS_FILES" -eq 1 ]; then
  echo "Processing files..."

  # Process all .vcf files
  find "$SOURCE_DIR" -type f -name "*.vcf" -print0 |
  while read -r filepath; do
    # Get the relative path from source directory
    rel_path="${filepath#$SOURCE_DIR/}"
    dest_file="$DEST_DIR/$rel_path"
    dest_dir=$(dirname "$dest_file")
    
    # Create destination directory if it doesn't exist
    mkdir -p "$dest_dir"
    
    # Create backup of destination file if it exists
    if [ -f "$dest_file" ]; then
        backup_file="${dest_file}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$dest_file" "$backup_file"
        echo "Created backup: $backup_file"
    fi
    
    # Copy the modified file
    cp "$filepath" "$dest_file"

    # Process the copied file
    process_vcf_file "$dest_file"

    echo "Synced and processed: $rel_path"
  done
  
  echo "Processing complete."
fi