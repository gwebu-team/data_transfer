# File Transfer Script

This script is used for transferring files from a source directory to a destination directory on a remote server using SSH and netcat.

## Usage
To use the script, run it with the following arguments:
- `-s`: path to the source data directory
- `-r`: receiver host address
- `-p`: port number
- `-u`: username for the receiver host
- `-d`: destination path on the receiver
- `-l`: rate limit for the transfer
- `-q`: (optional) be quiet mode

Example:
```shell
./file_transfer.sh -s /path/to/source -r 192.168.0.2 -p 12345 -u username -d /path/on/receiver -l 1G
