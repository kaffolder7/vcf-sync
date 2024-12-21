#!/bin/bash
#
# VCF File Sync & Lock Script
# Copyright (c) 2024 Kyle Affolder
# Licensed under the MIT License. See LICENSE file in the project root
# for full license information.
#

set -euo pipefail  # Enable strict error handling

# Configuration
readonly EMOJI_TO_APPEND=" 🔒"
readonly TEMP_DIR="/tmp/vcf_sync_$$"  # Process-specific temp directory
readonly LOCKFILE="/tmp/vcf_sync.lock"
readonly MAX_CONCURRENT_JOBS=4        # Adjust based on your CPU cores

# Function to clean up temporary files on exit
cleanup() {
  rm -rf "$TEMP_DIR"
  rm -f "$LOCKFILE"
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Show usage information
show_usage() {
  cat << EOF
Usage: $0 [options] <source_directory> <destination_directory>

Syncs .vcf files from source to destination directory.

Options:
  -h, --help              Show this help message and exit
  -p, --process           Process VCF files (add lock emoji and update timestamps)
                          (If not specified, files will only be synced)

Examples:
  $0 ~/contacts ~/backup              # Sync files only
  $0 -p ~/contacts ~/backup           # Sync and process files
EOF
}

# Ensure only one instance runs
ensure_single_instance() {
  if ! mkdir "$LOCKFILE" 2>/dev/null; then
    echo "Error: Script is already running"
    exit 1
  fi
}

# Initialize logging
setup_logging() {
  exec 1> >(logger -s -t $(basename $0)) 2>&1
}

# Process a single VCF file
process_vcf_file() {
  local file="$1"
  local temp_file="$TEMP_DIR/$(basename "$file").tmp"
  
  # Skip if file already has lock emoji
  if grep -q "$EMOJI_TO_APPEND" "$file" 2>/dev/null; then
    return 0
  fi
  
  # Process file using awk for better performance
  awk -v lock="$EMOJI_TO_APPEND" -v current_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    BEGIN { OFS=FS=""; modified=0 }
    /^N:/ && !modified {
      pos=index($0, ";")
      if (pos > 0) {
        print substr($0, 1, pos-1) lock substr($0, pos)
        modified=1
        next
      }
    }
    /^REV:/ {
      print "REV:" current_time
      next
    }
    { print }
  ' "$file" > "$temp_file"

  # Atomically replace the original file
  mv -f "$temp_file" "$file"
}

# Parallel process multiple files
process_files_parallel() {
  local files=("$@")
  local num_files=${#files[@]}
  local jobs=0
  
  mkdir -p "$TEMP_DIR"
  
  for file in "${files[@]}"; do
    ((jobs >= MAX_CONCURRENT_JOBS)) && wait
    process_vcf_file "$file" &
    ((jobs++))
  done
  wait  # Wait for all background jobs to complete
}

# Optimize initial file copy
optimize_copy() {
  local src="$1"
  local dest="$2"
  local rel_path="${src#$SOURCE_DIR/}"
  local dest_file="$dest/$rel_path"
  local dest_dir=$(dirname "$dest_file")
  
  mkdir -p "$dest_dir"
  if [ ! -f "$dest_file" ] || [ "$src" -nt "$dest_file" ]; then
    cp -u "$src" "$dest_file"
    return 0  # File was copied
  fi
  return 1  # File was skipped
}

# Main script
main() {
  local PROCESS_FILES=0
  local SOURCE_DIR=""
  local DEST_DIR=""

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_usage
        exit 0
        ;;
      -p|--process)
        PROCESS_FILES=1
        shift
        ;;
      *)
        if [ -z "$SOURCE_DIR" ]; then
          SOURCE_DIR="$1"
        elif [ -z "$DEST_DIR" ]; then
          DEST_DIR="$1"
        else
          echo "Error: Unexpected argument '$1'" >&2
          show_usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate required arguments
  if [ -z "$SOURCE_DIR" ] || [ -z "$DEST_DIR" ]; then
    echo "Error: Source and destination directories are required" >&2
    show_usage
    exit 1
  fi

  # Validate directories
  if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist" >&2
    exit 1
  fi

  # Create destination if it doesn't exist
  mkdir -p "$DEST_DIR"
  mkdir -p "$TEMP_DIR"

  # Set up environment
  ensure_single_instance
  setup_logging
  
  echo "Starting initial sync..."
  
  # Initial copy and processing
  local -a files_to_process=()
  while IFS= read -r -d '' file; do
    if optimize_copy "$file" "$DEST_DIR"; then
      files_to_process+=("$DEST_DIR/${file#$SOURCE_DIR/}")
    fi
  done < <(find "$SOURCE_DIR" -type f -name "*.vcf" -print0)
  
  if [ ${#files_to_process[@]} -gt 0 ]; then
    echo "Processing ${#files_to_process[@]} files..."
    process_files_parallel "${files_to_process[@]}"
  fi
  
  echo "Initial sync complete."

  # Process VCF files if requested
  if [ "$PROCESS_FILES" -eq 1 ]; then
    echo "Processing files..."

    # Process all .vcf files
    find "$SOURCE_DIR" -type f -name "*.vcf" -print0 |
      while read -r filepath; do
        if [[ "$filepath" =~ \.vcf$ ]]; then
          rel_path="${filepath#$SOURCE_DIR/}"
          dest_file="$DEST_DIR/$rel_path"
          dest_dir=$(dirname "$dest_file")
          
          # Create destination directory if needed
          mkdir -p "$dest_dir"
          
          # Create backup if file exists
          if [ -f "$dest_file" ]; then
            cp -a "$dest_file" "${dest_file}.backup-$(date +%Y%m%d-%H%M%S)"
          fi
          
          # Copy and process the file
          cp "$filepath" "$dest_file"
          process_vcf_file "$dest_file"
          echo "Synced and processed: $rel_path"
        fi
      done

    echo "Processing complete."
  fi

  echo "All operations completed successfully"
}

# Run main function
main "$@"