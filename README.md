# VCF File Sync Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A bash script that synchronizes vCard (.vcf) files between directories.

## Features

- One-time synchronization of .vcf files between directories
- Automatic backup creation for existing files
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
./vcf_sync.sh /path/to/source /path/to/destination
```

The script will:
1. Create the destination directory if it doesn't exist
2. Perform an initial sync of all .vcf files
3. Update/sync changed .vcf files on each subsequent script execution

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