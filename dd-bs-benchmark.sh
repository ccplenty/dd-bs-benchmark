#!/usr/bin/env bash


#----------------------------------------------------------------------
#  Enable some bash options
#----------------------------------------------------------------------
set -e    # aka errexit, this option ensures the shell will exit on error
set -u    # aka nounset, this option treats unbound variables or parameters as an error
#set -x    # aka xtrace, this option displays the commands and the expanded values

#----------------------------------------------------------------------
#  Define some exit codes
#  (see /usr/include/sysexits.h)
#----------------------------------------------------------------------
EX_OK=0            # Successful termination
EX_USAGE=64        # The command was used incorrectly, e.g., with the wrong
                   #+ number of arguments, a bad flag, a bad syntax in a
                   #+ parameter, or whatever.
EX_NOINPUT=66      # An input file (not a system file) did not exist or was
                   #+ not readable. This could also include errors like "No
                   #+ message" to a mailer (if it cared to catch it).
#EX_UNAVAILABLE=69  # A service is unavailable. This can occur if a support
#                   #+ program or file does not exist. This can also be used
#                   #+ as a catchall message when something you wanted to do
#                   #+ doesn't work, but you don't know why.
EX_CANTCREAT=73    # A (user specified) output file cannot be created.

#===  FUNCTION  ================================================================
#         NAME:  show_help
#  DESCRIPTION:  Display usage information for this script
# PARAMETER  1:  ---
#===============================================================================
show_help () {
cat << EOF

Benchmark the device where DIRECTORY resides on using dd.

Usage: ${0##*/} -h | --help
Usage: ${0##*/} {{-r | --read} | {-w | --write}} DIRECTORY [NUMBER]

Options:
    -h, --help                      display this help and exit
    -r, --read                      run the script in read mode
    -w, --write                     run the script in write mode
    DIRECTORY                       a path to a directory
    NUMBER                          the number of bytes for the temporary file
                                    that is to be created. Default: 268435456

Examples:
${0##*/} --help
    Show this usage message.
${0##*/} -r /media/user/External_storage 536870912
    The command above will create a 512 MiB file with pseudo-random data in the
    directory /media/user/External_storage then read it back repeatedly with
    "dd" using different block sizes and print the read speeds obtained. If no
    size were specified, the script would create a file of the default size
    which is 256 MiB.
${0##*/} -w /media/user/External_storage
    The command above will create a zeroed-out file with "dd" using a block size
    of 512 bytes in the directory /media/user/External_storage and print the
    write speed obtained then delete the file. It would then create another file
    using a block size of 1024 bytes, then one with 2 kiB and so on. Because
    no size was specified, the script will create a file of the default size
    which is 256 MiB.

EOF
} >&2    # create a function to show an usage message and redirect it to STDERR

#----------------------------------------------------------------------
#  Parse the command line arguments using getopts
#----------------------------------------------------------------------
while getopts ":hrw-:" opt; do
  while true; do
    case "${opt}" in
      -)    #OPTARG is name-of-long-option or name-of-long-option=value
        if [[ ${OPTARG} =~ .*=.* ]]; then
          opt=${OPTARG/=*/}
          ((${#opt} <= 1)) && {
            echo "Syntax error: Invalid long option '$opt'" >&2
            #exit 2
            exit $EX_USAGE
          }
          OPTARG=${OPTARG#*=}
        else
          opt="$OPTARG"
          ((${#opt} <= 1)) && {
            echo "Syntax error: Invalid long option '$opt'" >&2
            #exit 2
            exit $EX_USAGE
          }
        fi
        continue    # now that opt/OPTARG are set we can process them as if
                    #+ getopts would've given us long options
        ;;
      h|help)
        echo "The -h/--help flag was used"
        show_help
        exit $EX_OK
        ;;
      r|read)
        echo "The -r/--read flag was used"
        r_flag=1
      ;;
      w|write)
        echo "The -w/--write flag was used"
        w_flag=1
      ;;
      ?)
        echo "Syntax error: Unknown short option -${OPTARG:-}" >&2
        #exit 2
        exit $EX_USAGE
        ;;
      *)
        echo "Syntax error: Unknown long option --${opt[0]}" >&2
        #exit 2
        exit $EX_USAGE
        ;;
    esac
  break; done
done

#----------------------------------------------------------------------
#  Stop the script if no valid flags were used
#----------------------------------------------------------------------
if [[ ! ${r_flag:-} && ! ${w_flag:-} ]]; then
  echo "Please choose one of the 2 options: -r/--read or -w/--write)."
  exit $EX_USAGE
fi

#----------------------------------------------------------------------
#  Stop the script if both flags were used
#----------------------------------------------------------------------
if [[ ${r_flag:-} && ${w_flag:-} ]]; then
  echo "The -r/--read and -w/--write flags are mutually exclusive" >&2
  echo "You can either run the script in read mode or in write mode." >&2
  exit $EX_USAGE
fi

#----------------------------------------------------------------------
#  Extract the directory path and the file size
#----------------------------------------------------------------------
#echo "First non-option-argument (if exists): ${!OPTIND-}"
if [[ "${!OPTIND-}" ]]; then    # check if there are any non-option arguments
  shift "$((OPTIND-1))"    # remove all the options that were parsed by getopts
#  echo "\"\$#\":$#"    # show the number of arguments
#  echo "\"\$0\":$0"    # show the script path
#  echo "\"\$1\":$1"    # show the first argument
#  echo "\"\$2\":$2"    # show the second argument
#  echo "\"\$3\":$3"    # show the third argument
  echo "The directory path was specified: ${1}"
  path="${1}"
  temporary_file="$path/dd-bs-benchmark.tmp"
  if [[ "${2:-}" ]]; then
    echo "The file size was specified: ${2}"
    temporary_file_size="${2}"
    # Check if the provided number is valid
    case "$temporary_file_size" in
      (*[!0-9]*|'')
        echo "Please specify a file size that is a natural number/positive integer."
        exit $EX_USAGE
      ;;
      (*)
        echo "The file will be $temporary_file_size bytes large."
      ;;
    esac
  else
    echo "The file size was not specified."
    echo "The default file size of 256 MiB will be used."
    temporary_file_size=268435456
  fi
else
  echo "Please provide a directory path."
  exit $EX_USAGE
fi

#----------------------------------------------------------------------
#  Create some variables
#----------------------------------------------------------------------
# Benchmark with block sizes from 512 bytes to 64 MiB
block_sizes="512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864"
if [[ ${r_flag:-} ]]; then
  printf_format="%10s - %10s\n"
fi
if [[ ${w_flag:-} ]]; then
  printf_format="%10s - %11s\n"
fi

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
if [[ -d "$path" ]]; then
  if [[ -w "$path" ]]; then
    echo "The directory $path is valid"
  else
    echo "The directory $path is not writable."
    exit $EX_CANTCREAT
  fi
else
  echo "The path $path is not of a directory, please provide a valid one."
  exit $EX_NOINPUT
fi

#----------------------------------------------------------------------
#  Abort the benchmark if the file exists
#----------------------------------------------------------------------
if [[ -e $temporary_file ]]; then
  echo "The file $temporary_file exists, please provide another file path."
  exit $EX_USAGE
fi

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
    # shellcheck disable=SC2059
    printf "$printf_format" 'block size' 'read speed'
  fi

  if [[ ${w_flag:-} ]]; then
    # Print a header for the list with the write speeds
    # shellcheck disable=SC2059
    printf "$printf_format" 'block size' 'write speed'
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
      # shellcheck disable=SC2059
      printf "$printf_format" "$bs" "$read_speed"
    fi

    if [[ ${w_flag:-} ]]; then
      # Create a temporary file using the $bs block size
      dd_output=$(dd bs="$bs" conv=fsync count=$count if=/dev/zero of="$temporary_file" 2>&1 1>/dev/null)

      # Determine the write speed from dd's output and place it in a variable
      write_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

      # Print the current benchmark's write speed
      # shellcheck disable=SC2059
      printf "$printf_format" "$bs" "$write_speed"

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
