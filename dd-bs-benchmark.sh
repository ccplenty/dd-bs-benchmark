#!/usr/bin/env bash


#----------------------------------------------------------------------
#  Enable some bash options
#----------------------------------------------------------------------
set -e    # aka errexit, this option ensures the shell will exit on error
set -u    # aka nounset, this option treats unbound variables or parameters as an error
#set -x    # aka xtrace, this option displays the commands and the expanded values

#----------------------------------------------------------------------
#  Parse the command line arguments with getopts
#----------------------------------------------------------------------
while getopts ":rw" opt; do
  case "$opt" in
    r)
      echo "-r flag was triggered"
      r_flag=1
    ;;
    w)
      echo "-w flag was triggered"
      w_flag=1
    ;;
    ?)
      echo "Invalid option: -${OPTARG:-}" >&2
      echo "Usage: ${0##*/} -r|-w DIRECTORY [NUMBER]"
      exit 1
    ;;
  esac
done

#----------------------------------------------------------------------
#  Stop the script if no valid flags were used
#----------------------------------------------------------------------
if [[ ! ${r_flag:-} && ! ${w_flag:-} ]]; then
  echo "Please choose one of the 2 options: -r (read) or -w (write)."
  echo "Usage: ${0##*/} -r|-w DIRECTORY [NUMBER]"
  exit 1
fi

#----------------------------------------------------------------------
#  Stop the script if both flags were used
#----------------------------------------------------------------------
if [[ ${r_flag:-} && ${w_flag:-} ]]; then
  echo "The -r and -w flags are mutually exclusive" >&2
  echo "You can either run the script in read mode or in write mode." >&2
  exit 1
fi

#----------------------------------------------------------------------
#  Create some variables
#----------------------------------------------------------------------
if [[ "${2:-}" ]]; then
  path="${2}"
else
  echo "Please provide a directory path!"
  echo "Usage: ${0##*/} -r|-w DIRECTORY [NUMBER]"
  exit 1
fi
temporary_file="$path/dd-ibs-benchmark.tmp"
if [[ "${3:-}" ]]; then temporary_file_size="${3}"; else temporary_file_size=268435456; fi
# Benchmark with block sizes from 512 bytes to 64 MiB
block_sizes="512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864"

#----------------------------------------------------------------------
#  Check if the script is run as root
#----------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "NOTE: The kernel cache cannot be cleared without root privileges." >&2
  echo "To avoid inaccurate results please run this script as root." >&2
fi

#----------------------------------------------------------------------
#  Check if the directory is valid
#----------------------------------------------------------------------
if [[ ! -d $path || ! -w $path ]]; then
  echo "$path is not a directory or is not writable, please provide another path."
  exit 1
fi

#----------------------------------------------------------------------
#  Abort the benchmark if the file exists
#----------------------------------------------------------------------
if [[ -e $temporary_file ]]; then
  echo "The file $temporary_file exists, please provide another file path."
  exit 1
fi

#----------------------------------------------------------------------
#  Check if the provided number is valid
#----------------------------------------------------------------------
case "$temporary_file_size" in
  (*[!0-9]*|'') echo "Please specify a file size that is a natural number/positive integer!";;
  (*)           echo "The file will be $temporary_file_size bytes large.";;
esac

#----------------------------------------------------------------------
#  Use a code block where to create the file
#----------------------------------------------------------------------
{

  if [[ ${r_flag:-} ]]; then
    # Generate a temporary file with random data
    echo "Please wait while the file $temporary_file is being written."
    bs=65536
    count=$((temporary_file_size / bs))
    dd bs=$bs conv=fsync count=$count if=/dev/urandom of="$temporary_file" &> /dev/null

    # Print a header for the list with the read speeds
    echo "block  |  read"
    echo " size  |  speed"
  fi

  if [[ ${w_flag:-} ]]; then
    # Print a header for the list with the write speeds
    echo "block  |  write"
    echo " size  |  speed"
  fi

  #--------------------------------------------------------------------
  #  Run benchmarks for each block size
  #--------------------------------------------------------------------
  for bs in $block_sizes; do

    if [[ ${w_flag:-} ]]; then
      # Calculate the number of blocks needed to create the file
      count=$((temporary_file_size / bs))
    fi

    # Clear the kernel cache to obtain more accurate results
    sync && [[ $EUID -eq 0 ]] && [[ -e /proc/sys/vm/drop_caches ]] && sysctl vm.drop_caches=3

    if [[ ${r_flag:-} ]]; then
      # Read the temporary file using the $bs block size and send the data to /dev/null
      dd_output=$(dd bs="$bs" if="$temporary_file" of=/dev/null 2>&1 1>/dev/null)

      # Determine the read speed from dd's output and place it in a variable
      read_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

      # Print the current benchmark's read speed
      echo "  $bs  -  $read_speed"
    fi

    if [[ ${w_flag:-} ]]; then
      # Create a temporary file using the $bs block size
      dd_output=$(dd bs="$bs" conv=fsync count=$count if=/dev/zero of="$temporary_file" 2>&1 1>/dev/null)

      # Determine the write speed from dd's output and place it in a variable
      write_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

      # Print the current benchmark's write speed
      echo "  $bs  -  $write_speed"

      # Remove the temporary file
      rm "$temporary_file"

    fi
  done

  if [[ ${r_flag:-} ]]; then
    # Remove the temporary file
    rm "$temporary_file"
  fi

} || {    # if any command above fails, a fallback code block is ran

  # Remove the temporary file
  rm "$temporary_file"

}
