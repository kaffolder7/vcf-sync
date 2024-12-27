# VCF File Sync & Lock Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A bash script that efficiently synchronizes and processes vCard (.vcf) files between directories while adding visual lock indicators to contact names.

## Features

- Efficient file synchronization using _rsync_
- Real-time synchronization of .vcf files between directories
- Automatic backup creation with timestamps
- Visual lock indicator (🔒) added to contact names
- Automatic timestamp updates
- Parallel processing of files (for better performance)

## Prerequisites

The script requires:

- _rsync_ (pre-installed on most Unix systems)
- _watchexec_ (for file monitoring)
- Standard Unix utilities (_awk_, _grep_, etc.)

To install _rsync_ and _watchexec_ if not present:

```bash
## macOS
brew install watchexec

## Linux via package manager & Cargo

  # Ubuntu/Debian*
  sudo apt-get install rsync
  cargo install watchexec-cli

  # RedHat/CentOS*
  sudo yum install rsync
  cargo install watchexec-cli

# Or download the appropriate binary from:
# https://github.com/watchexec/watchexec/releases
```

## Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/kaffolder7/vcf-sync/watchexec/vcf_sync.sh
```

2. Make it executable:
```bash
chmod +x vcf_sync.sh
```

## Usage

Run the script with source and destination directories as arguments:

```bash
# One-time sync only
./vcf_sync.sh ~/path/to/source ~/path/to/destination

# Watch and sync continuously
./vcf_sync.sh -w ~/path/to/source ~/path/to/destination

# Watch, sync and process files continuously
./vcf_sync.sh -w -p ~/path/to/source ~/path/to/destination

# Show help
./vcf_sync.sh --help
```

Options:
- Without `-w`: Perform a single sync operation and exit
- With `-w`: Start in watch mode and continuously sync changes
- With `-p`: Process files (add lock emoji) regardless of watch mode

The script will:
1. Efficiently sync .vcf files from source to destination directory using _rsync_
      - Create the destination directory if it doesn't exist
2. Create timestamped backups of modified files
3. Process each file to add lock indicators and update timestamps
4. Handle all operations in parallel for better performance
5. Monitor for changes and sync automatically
      - You can choose between one-time sync or continuous watching

## File Processing

For each .vcf file that doesn't already contain a lock indicator, the script will:

1. Add a lock emoji (🔒) to the contact's name
   - Example: `N:Smith;John;;;` becomes `N:Smith 🔒;John;;;`
2. Update the REV field with the current timestamp in ISO 8601 format
   - Example: `REV:2023-04-15T12:34:56Z` becomes `REV:2024-12-19T14:30:25Z`

## How It Works

The script combines two powerful approaches:
1. Uses _rsync_'s efficient file synchronization algorithm to:
      - Only copy changed files
      - Create automatic backups
      - Preserve file attributes
      - Handle large directory structures efficiently

2. Uses parallel processing to:
      - Add lock emojis to contact names
      - Update timestamps
      - Process multiple files simultaneously

## Backup System

The script automatically creates backups of existing files in the destination:
- Backups are stored in the same directory as the original file
- Backup files are named with timestamps (e.g., `contact.vcf.backup-20241219-143025`)

## Performance Features

- _rsync_'s delta-transfer algorithm minimizes data transfer
- Parallel processing of file modifications (configurable number of concurrent jobs)
- Efficient file change detection
- Skips already processed files
- Uses efficient file processing with _awk_
- Handles large numbers of files efficiently

## Error Handling

- Validates all required tools are installed
- Cleans up temporary files on exit
- Provides detailed progress information
- Maintains atomic file operations

## Limitations

- Requires _watchexec_ package
- Only processes .vcf files

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2024 Kyle Affolder