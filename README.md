# VCF File Sync & Lock Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A bash script that efficiently synchronizes vCard (.vcf) files between directories while adding visual lock indicators to contact names. Uses _rsync_ for efficient file synchronization and parallel processing for custom modifications.

## Features

- Efficient file synchronization using _rsync_
- Automatic backup creation with timestamps
- Visual lock indicator (🔒) added to contact names
- Automatic timestamp updates
- Parallel processing of files
- Cross-platform compatibility

## Prerequisites

The script requires:

- _rsync_ (pre-installed on most Unix systems)
- Standard Unix utilities (awk, grep, etc.)

To install rsync if not present:

```bash
# macOS
brew install rsync

# Ubuntu/Debian
sudo apt-get install rsync

# RedHat/CentOS
sudo yum install rsync
```

## Installation

1. Download the script:
```bash
wget https://your-script-location/vcf_sync.sh
```

2. Make it executable:
```bash
chmod +x vcf_sync.sh
```

## Usage

Run the script with source and destination directories as arguments:

```bash
# Sync files only
./vcf_sync.sh /path/to/source /path/to/destination

# Sync and process files (add lock emoji and update timestamps)
./vcf_sync.sh -p /path/to/source /path/to/destination
```

The script will:
1. Efficiently sync .vcf files from source to destination using rsync
2. Create timestamped backups of modified files
3. Process each file to add lock indicators and update timestamps
4. Handle all operations in parallel for better performance

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
- Parallel processing of file modifications
- Efficient file change detection
- Skips already processed files
- Handles large numbers of files efficiently

## Error Handling

- Validates all required tools are installed
- Cleans up temporary files on exit
- Provides detailed progress information
- Maintains atomic file operations

## Limitations

- Only processes .vcf files

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2024 Kyle Affolder