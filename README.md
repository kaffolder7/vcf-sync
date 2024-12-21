# VCF File Sync & Lock Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A bash script that synchronizes and processes vCard (.vcf) files between directories while adding visual lock indicators to contact names.

## Features

- One-time synchronization of .vcf files between directories
- Automatic backup creation for existing files
- Visual lock indicator (🔒) added to contact names
- Automatic timestamp updates

## Prerequisites

The script requires the following:

- Bash shell

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
1. Create the destination directory if it doesn't exist
2. Copy all .vcf files from source to destination
3. Create backups of any existing files in the destination
4. Process each file to add lock indicators and update timestamps
5. Update/sync changed .vcf files on each subsequent script execution

## File Processing

For each .vcf file that doesn't already contain a lock indicator, the script will:

1. Add a lock emoji (🔒) to the contact's name
   - Example: `N:Smith;John;;;` becomes `N:Smith 🔒;John;;;`
2. Update the REV field with the current timestamp in ISO 8601 format
   - Example: `REV:2023-04-15T12:34:56Z` becomes `REV:2024-12-19T14:30:25Z`

## Backup System

The script automatically creates backups of existing files in the destination:
- Backups are stored in the same directory as the original file
- Backup files are named with timestamps (e.g., `contact.vcf.backup-20241219-143025`)

## Limitations

- Only processes .vcf files

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2024 Kyle Affolder