#!/bin/bash
#
# VCF File Watch & Sync Script
# Uses `inotify-tools` for file monitoring
# Copyright (c) 2024 [Your Name or Organization]
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

# Check if required tools are installed
check_dependencies() {
  local missing_deps=()
  
  if ! command -v rsync >/dev/null 2>&1; then
    missing_deps+=("rsync")
  fi
  
  if ! command -v inotifywait >/dev/null 2>&1; then
    missing_deps+=("inotify-tools")
  fi
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "Error: Missing required dependencies: ${missing_deps[*]}"
    echo "Please install them using your package manager:"
    echo "On Ubuntu/Debian:"
    echo "  sudo apt-get install ${missing_deps[*]}"
    echo "On RedHat/CentOS:"
    echo "  sudo yum install ${missing_deps[*]}"
    exit 1
  fi
}

# Function to sync files
sync_files() {
  local source_dir="$1"
  local dest_dir="$2"
  local process_files="$3"
  
  echo "Syncing changes..."
  
  # Use rsync to sync .vcf files
  rsync -av \
    --backup \
    --suffix=".backup-$(date +%Y%m%d-%H%M%S)" \
    --include='*.vcf' \
    --include='*/' \
    --exclude='*' \
    --prune-empty-dirs \
    "${source_dir}/" "${dest_dir}/"
    
  # Process files if requested
  if [ "$process_files" -eq 1 ]; then
    echo "Processing changed files..."
    find "$dest_dir" -type f -name "*.vcf" -print0 | \
      xargs -0 -P "$MAX_CONCURRENT_JOBS" -I {} bash -c 'process_vcf_file "$@"' _ {}
  fi
  
  echo "Sync complete."
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

# Watch directory for changes using inotifywait
watch_directory() {
  local source_dir="$1"
  local dest_dir="$2"
  local process_files="$3"
  
  echo "Performing initial sync..."
  sync_files "$source_dir" "$dest_dir" "$process_files"
  
  echo "Watching for changes..."
  
  # Use inotifywait to monitor for changes
  # -m: monitor continuously
  # -r: watch recursively
  # -e: specify events to watch
  # --format: specify the output format
  inotifywait -m -r \
    # -e create -e modify -e moved_to \
    -e create,modify,moved_to \
    # -e modify,create,delete,move \
    --format '%w%f' \
    --include '.*\.vcf$' \
    "$source_dir" | while read -r changed_file; do
      # Add a small delay to handle rapid successive changes
      sleep 0.5
      
      # Only sync if the changed file still exists
      # (handles cases where files are quickly deleted after creation)
      if [ -f "$changed_file" ]; then
        echo "Change detected in: $changed_file"
        sync_files "$source_dir" "$dest_dir" "$process_files"
      fi
  done
}

# Show usage information
show_usage() {
  cat << EOF
Usage: $0 [options] <source_directory> <destination_directory>

Watches and syncs .vcf files from source to destination directory.
Designed for Linux systems using inotify-tools.

Options:
  -h, --help              Show this help message and exit
  -w, --watch             Watch for changes and sync continuously
  -p, --process           Process VCF files (add lock emoji and update timestamps)
                          If not specified, files will only be synced

Examples:
  $0 ~/contacts ~/backup              # Sync files once
  $0 -w ~/contacts ~/backup          # Watch and sync files continuously
  $0 -w -p ~/contacts ~/backup       # Watch, sync and process files continuously

Required tools:
  - rsync: For efficient file synchronization
  - inotify-tools: For Linux file monitoring

Installation:
  Ubuntu/Debian:
    sudo apt-get install rsync inotify-tools

  RedHat/CentOS:
    sudo yum install rsync inotify-tools
EOF
}

# Main script
main() {
  local PROCESS_FILES=0
  local WATCH_MODE=0
  local SOURCE_DIR=""
  local DEST_DIR=""

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_usage
        exit 0
        ;;
      -w|--watch)
        WATCH_MODE=1
        shift
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

  # Check dependencies only if watch mode is enabled
  if [ "$WATCH_MODE" -eq 1 ]; then
    check_dependencies
  elif ! command -v rsync >/dev/null 2>&1; then
    echo "Error: rsync is required for file synchronization"
    echo "Please install rsync using your package manager:"
    echo "  Ubuntu/Debian: sudo apt-get install rsync"
    echo "  RedHat/CentOS: sudo yum install rsync"
    exit 1
  fi

  # Perform initial sync
  sync_files "$SOURCE_DIR" "$DEST_DIR" "$PROCESS_FILES"
  
  # Start watching if watch mode is enabled
  if [ "$WATCH_MODE" -eq 1 ]; then
    echo "Starting watch mode..."
    watch_directory "$SOURCE_DIR" "$DEST_DIR" "$PROCESS_FILES"
  fi
}

# Run main function
main "$@"