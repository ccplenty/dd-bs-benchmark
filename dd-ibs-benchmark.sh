#!/usr/bin/env bash


set -e
set -u
#set -x

if [[ "${1:-}" ]]; then
  path="${1}"
else
  echo "Please provide a directory path!"
  echo "Usage: ${0##*/} -r|-w DIRECTORY [NUMBER]"
  exit 1
fi
temporary_file="$path/dd-ibs-benchmark.tmp"
if [[ "${2:-}" ]]; then temporary_file_size="${2}"; else temporary_file_size=268435456; fi
block_sizes="512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864"

if [[ $EUID -ne 0 ]]; then
  echo "NOTE: The kernel cache cannot be cleared without root privileges." >&2
  echo "To avoid inaccurate results please run this script as root." >&2
fi

if [[ ! -d $path || ! -w $path ]]; then
  echo "$path is not a directory or is not writable, please provide another path."
  exit 1
fi

if [[ -e $temporary_file ]]; then
  echo "The file $temporary_file exists, please provide another file path."
  exit 1
fi

case "$temporary_file_size" in
  (*[!0-9]*|'') echo "Please specify a file size that is a natural number/positive integer!";;
  (*)           echo "The file will be $temporary_file_size bytes large.";;
esac

{
  echo "Please wait while the file $temporary_file is being written."
  bs=65536
  count=$((temporary_file_size / bs))
  dd bs=$bs conv=fsync count=$count if=/dev/urandom of="$temporary_file" &> /dev/null

  echo "block  |  read"
  echo " size  |  speed"

  for bs in $block_sizes; do

    sync && [[ $EUID -eq 0 ]] && [[ -e /proc/sys/vm/drop_caches ]] && sysctl vm.drop_caches=3

    dd_output=$(dd bs="$bs" if="$temporary_file" of=/dev/null 2>&1 1>/dev/null)

    read_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

    echo "  $bs  -  $read_speed"

  done

  rm "$temporary_file"
} || {
  rm "$temporary_file"
}
