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
readonly MAX_CONCURRENT_JOBS=4        # Adjust based on your CPU cores

# Function to clean up temporary files on exit
cleanup() {
  rm -rf "$TEMP_DIR"
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

# Check if rsync is installed
check_rsync() {
  if ! command -v rsync >/dev/null 2>&1; then
    echo "Error: rsync is not installed. Please install it first."
    echo "On macOS: brew install rsync"
    echo "On Ubuntu/Debian: sudo apt-get install rsync"
    echo "On RedHat/CentOS: sudo yum install rsync"
    exit 1
  fi
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

  # Validate arguments
  if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>" >&2
    exit 1
  fi

  # Validate directories
  if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist" >&2
    exit 1
  fi

  # Check for rsync
  check_rsync

  # Create destination if it doesn't exist
  mkdir -p "$DEST_DIR"
  mkdir -p "$TEMP_DIR"
  
  echo "Starting sync..."
  
  # Use rsync to sync .vcf files
  rsync -av \
    --backup \
    --suffix=".backup-$(date +%Y%m%d-%H%M%S)" \
    --include='*.vcf' \
    --include='*/' \
    --exclude='*' \
    --prune-empty-dirs \
    "${SOURCE_DIR}/" "${DEST_DIR}/"

  echo "Sync complete."

  # Process files if requested
  if [ "$PROCESS_FILES" -eq 1 ]; then
    echo "Processing files..."

    # Process all .vcf files in parallel
    find "$DEST_DIR" -type f -name "*.vcf" -print0 | \
      xargs -0 -P "$MAX_CONCURRENT_JOBS" -I {} bash -c 'process_vcf_file "$@"' _ {}
    
    echo "Processing complete."
  fi

  echo "All operations completed successfully"
}

# Run main function
main "$@"