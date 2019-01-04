#!/usr/bin/env bash


# Enable some bash options
set -e    # aka errexit, this option ensures the shell will exit on error
set -u    # aka nounset, this option treats unbound variables or parameters as an error
#set -x    # aka xtrace, this option displays the commands and the expanded values

# Create some variables
if [[ "${1:-}" ]]; then
  path="${1}"
else
  echo "Please provide a directory path!"
  echo "Usage: ${0##*/} -r|-w DIRECTORY [NUMBER]"
  exit 1
fi
temporary_file="$path/dd-ibs-benchmark.tmp"
if [[ "${2:-}" ]]; then temporary_file_size="${2}"; else temporary_file_size=268435456; fi
# Test with block sizes from 512 bytes to 64 MiB
block_sizes="512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864"

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "NOTE: The kernel cache cannot be cleared without root privileges." >&2
  echo "To avoid inaccurate results please run this script as root." >&2
fi

# Check if the directory is valid
if [[ ! -d $path || ! -w $path ]]; then
  echo "$path is not a directory or is not writable, please provide another path."
  exit 1
fi

# Abort the test if the file exists
if [[ -e $temporary_file ]]; then
  echo "The file $temporary_file exists, please provide another file path."
  exit 1
fi

# Check if the provided number is valid
case "$temporary_file_size" in
  (*[!0-9]*|'') echo "Please specify a file size that is a natural number/positive integer!";;
  (*)           echo "The file will be $temporary_file_size bytes large.";;
esac

# Use a code block where to create the file
{

  # Generate a temporary file with random data
  echo "Please wait while the file $temporary_file is being written."
  bs=65536
  count=$((temporary_file_size / bs))
  dd bs=$bs conv=fsync count=$count if=/dev/urandom of="$temporary_file" &> /dev/null

  # Print a header for the list with the read speeds
  echo "block  |  read"
  echo " size  |  speed"

  # Run tests for each block size
  for bs in $block_sizes; do

    # Clear the kernel cache to obtain more accurate results
    sync && [[ $EUID -eq 0 ]] && [[ -e /proc/sys/vm/drop_caches ]] && sysctl vm.drop_caches=3

    # Read the temporary file using the $bs block size and send the data to /dev/null
    dd_output=$(dd bs="$bs" if="$temporary_file" of=/dev/null 2>&1 1>/dev/null)

    # Determine the read speed from dd's output and place it in a variable
    read_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

    # Print the current test's read speed
    echo "  $bs  -  $read_speed"

  done

  # Remove the temporary file
  rm "$temporary_file"

} || {    # if any command above fails, a fallback code block is ran

  # Remove the temporary file
  rm "$temporary_file"

}
