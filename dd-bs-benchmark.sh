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
E_OK=0            # Successful termination
E_USAGE=64        # The command was used incorrectly, e.g., with the wrong
                  #+ number of arguments, a bad flag, a bad syntax in a
                  #+ parameter, or whatever.
E_NOINPUT=66      # An input file (not a system file) did not exist or was
                  #+ not readable. This could also include errors like "No
                  #+ message" to a mailer (if it cared to catch it).
#E_UNAVAILABLE=69  # A service is unavailable. This can occur if a support
#                  #+ program or file does not exist. This can also be used
#                  #+ as a catchall message when something you wanted to do
#                  #+ doesn't work, but you don't know why.
E_CANTCREAT=73    # A (user specified) output file cannot be created.

#----------------------------------------------------------------------
#  Check if the script is run as root
#----------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "NOTE: The kernel cache cannot be cleared without root privileges." >&2
  echo "To avoid inaccurate results please run this script as root." >&2
fi

#===  FUNCTION  ================================================================
#         NAME:  show_help
#  DESCRIPTION:  Display usage information for this script
# PARAMETER  1:  ---
#===============================================================================
show_help () {
cat << EOF

Benchmark the device where DIRECTORY resides on using dd.
Usage: ${0##*/} -h | --help
Usage: ${0##*/} {{-r | --read} | {-w | --write}}
                [{-m{""|" "}NUMBER} | {--min-block-size{" "|"="}NUMBER}]
                [{-M{""|" "}NUMBER} | {--max-block-size{" "|"="}NUMBER}]
                [{-t{""|" "}DIRECTORY} | {--temp{" "|"="}DIRECTORY}]
                DIRECTORY [NUMBER]

Benchmark the block device pointed to by BLOCK_DEVICE using dd.
Usage: ${0##*/} {{-r | --read} | {-w | --write}}
                [{-m{""|" "}NUMBER} | {--min-block-size{" "|"="}NUMBER}]
                [{-M{""|" "}NUMBER} | {--max-block-size{" "|"="}NUMBER}]
                [{-t{""|" "}DIRECTORY} | {--temp{" "|"="}DIRECTORY}]
                [-b | --block-device] BLOCK_DEVICE [NUMBER]

Options:
    -b, --block-device              benchmark a raw device, regardless of any
                                    file systems present on it. Warning: it
                                    causes data corruption
    -h, --help                      display this help and exit
    -m, --min-block-size NUMBER     minimum block size to be tested. Default: 512
    -M, --max-block-size NUMBER     maximum block size to be tested. Default: 67108864
    -r, --read                      run the script in read mode
    -t, --temp DIRECTORY            specify a directory where to place a
                                    temporary file generated with pseudo-random
                                    data. Only useful with the -w/--write flag
    -w, --write                     run the script in write mode
    DIRECTORY                       a path to a directory
    BLOCK_DEVICE                    a path to a block device
    NUMBER                          the size of the data in bytes to be read or
                                    written to the file that is to be created or
                                    to the block device. Default: 268435456

NOTE: Short options can have one space (" ") or no space before their arguments
      and long options can have one space (" ") or the equal sign ("=").

Examples:
${0##*/} --help
    Show this usage message.
${0##*/} -r /media/user/External_storage 536870912
    The command above will create a 512 MiB file with "dd" containing
    pseudo-random data in the directory /media/user/External_storage then read
    it back repeatedly with "dd" using different block sizes and print the read
    speeds obtained. If no size were specified, the script would create a file
    of the default size which is 256 MiB.
${0##*/} -w -m 1024 -M 33554432 /media/user/External_storage
    The command above will create a zeroed-out file with "dd" using a block size
    of 1024 bytes in the directory /media/user/External_storage and print the
    write speed obtained then delete the file. It would then create another file
    using a block size of 2048 bytes, and in the end, one with 32 MiB. Because
    no size was specified, the script will create files of the default size
    which is 256 MiB.
${0##*/} -t /dev/shm -w /media/user/External_storage 134217728
    By default, with the -w/--write flag, the script will create a file filled
    with zeroes by reading /dev/zero. If the -t/--temp flag is used, the script
    will generate a file with random data from /dev/urandom. Reading from
    /dev/urandom is a CPU-intensive operation and because, apparently, dd uses
    only 1 CPU, it would not be possible to benchmark a fast device like an SSD
    or maybe even a hard drive by reading from /dev/urandom because it could
    not read from it fast enough. A solution would be to read from /dev/urandom
    and create a file in a temporary directory on a fast drive then copy the
    file from the fast drive to the drive that needs to be benchmarked.
    The command above does what the previous one did but the -t flag will create
    a file with pseudo-random data in /dev/shm, which is a temporary directory
    stored in the RAM (hence, very fast) on Linux systems then copy it multiple
    times with different block sizes to /media/user/External_storage.
${0##*/} -b -t /dev/shm -w /dev/sdd 134217728
    The command above does what the previous one did but the -b flag tells the
    script to expect for a path to a block device instead of a directory.
    It will then write to it, starting with the first sector which means that it
    will overwrite the partition table and many more other sectors to a total of
    134217728 sectors.
EOF
} >&2    # create a function to show an usage message and redirect it to STDERR

#===  FUNCTION  ================================================================
#         NAME:  validate_directory
#  DESCRIPTION:  Check if a directory fulfills specific conditions
# PARAMETER  1:  The path to the directory
# PARAMETER  2:  The minimum free disk space its parent file system should have
#===============================================================================
validate_directory () {
  local dir_path
  dir_path="$1"
  local min_free_space
  min_free_space="$2"
  if [[ -e "$dir_path" ]]; then
    if [[ -d "$dir_path" ]]; then
      if [[ -w "$dir_path" ]]; then
        if [[ $(df --output=avail -B 1 "$dir_path" | tail -n 1) -gt "$min_free_space" ]]; then
          echo "The directory $dir_path is valid"
        else
          echo "There is not sufficient free space on the file system containing"
          echo "the directory $dir_path. Please free up some disk space."
          exit $E_CANTCREAT
       fi
      else
        echo "The directory $dir_path is not writable."
        exit $E_CANTCREAT
      fi
    else
      echo "The path $dir_path is not of a directory, please provide a valid one."
      exit $E_NOINPUT
    fi
  else
    echo "$dir_path is missing or you misspelled the path."
    echo "Please check again."
    exit $E_NOINPUT
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  validate_number
#  DESCRIPTION:  Check if a number is a natural number/positive integer
# PARAMETER  1:  A number
#===============================================================================
validate_number () {
  local number
  number="$1"
  case "$number" in
    (*[!0-9]*|'')
      echo "The number $number is not valid."
      echo "Please specify a file size that is a natural number/positive integer."
      exit $E_USAGE
    ;;
    (*)
      echo "The number $number is valid."
    ;;
  esac
}

#----------------------------------------------------------------------
#  Parse the command line arguments using getopts
#----------------------------------------------------------------------
# set defaults
i=$(($# + 1))    # index of the first non-existing argument
declare -A longoptspec
# Use associative array to declare how many arguments a long option expects.
# In this case we declare that all the options expect/have one argument. Long
#+ options that aren't listed in this way will have zero arguments by default.
longoptspec=( [min-block-size]=1 [max-block-size]=1 [temp]=1 )    # WARNING: bashism
while getopts ":bhm:M:rt:w-:" opt; do
  while true; do
    case "${opt}" in
      -)    #OPTARG is name-of-long-option or name-of-long-option=value
        if [[ ${OPTARG} =~ .*=.* ]]; then    # with this --key=value format
                                             #+ only one argument is possible
          opt=${OPTARG/=*/}
          ((${#opt} <= 1)) && {
            echo "Syntax error: Invalid long option '$opt'" >&2
            #exit 2
            exit $E_USAGE
          }
          if (($((longoptspec[$opt])) != 1)); then    # the script works with
                                                      #+ and w/o the $ in $opt
            echo "Syntax error: Option '$opt' does not support this syntax." >&2
            #exit 2
            exit $E_USAGE
          fi
          OPTARG=${OPTARG#*=}
        else    # with this --key value1 value2 format multiple arguments are
                #+ possible
          opt="$OPTARG"
          ((${#opt} <= 1)) && {
            echo "Syntax error: Invalid long option '$opt'" >&2
            #exit 2
            exit $E_USAGE
          }
          # TODO: do something to fix this mess below
          #OPTARG=(${@:OPTIND:$((longoptspec[$opt]))})    # this confuses Geany
          #OPTARG=("${@:OPTIND:$((longoptspec[$opt]))}")
          #OPTARG=("${@:OPTIND:${longoptspec[opt]}}")
          #OPTARG="${@:OPTIND:$((longoptspec[$opt]))}"
          OPTARG="${*:OPTIND:$((longoptspec[$opt]))}"    # the script doesn't
                                                         #+ work without the
                                                         #+ $ in $opt
          ((OPTIND+=longoptspec[$opt]))    # the script doesn't work without the
                                           #+ $ in $opt
          #echo $OPTIND
          ((OPTIND > i)) && {
            echo -n "Syntax error: Not all required arguments for option " >&2
            echo "'$opt' are given." >&2
            #exit 3
            exit $E_USAGE
          }
        fi
        continue    # now that opt/OPTARG are set we can process them as if
                    #+ getopts would've given us long options
        ;;
      b|block-device)
        echo "The -b/--block-device flag was used"
        b_flag=1
        if [[ $EUID -ne 0 ]]; then
          echo "To use block devices 'dd' needs root privileges." >&2
          echo "Please run this script as root." >&2
          exit $E_NOINPUT
        fi
        ;;
      h|help)
        echo "The -h/--help flag was used"
        show_help
        exit $E_OK
        ;;
      m|min-block-size)
        echo "The -m/--min-block-size flag was used"
        validate_number "$OPTARG" && min_block_size="$OPTARG"
        echo "The minimum block size of $min_block_size bytes will be used."
        ;;
      M|max-block-size)
        echo "The -M/--max-block-size flag was used"
        validate_number "$OPTARG" && max_block_size="$OPTARG"
        echo "The maximum block size of $max_block_size bytes will be used."
        ;;
      r|read)
        echo "The -r/--read flag was used"
        r_flag=1
        printf_format="%10s - %10s\n"
      ;;
      t|temp)
        echo "The -t/--temp flag was used"
        t_flag=1
        temp_dir="$OPTARG"
      ;;
      w|write)
        echo "The -w/--write flag was used"
        w_flag=1
        printf_format="%10s - %11s\n"
      ;;
      ?)
        echo "Syntax error: Unknown short option -${OPTARG:-}" >&2
        #exit 2
        exit $E_USAGE
        ;;
      *)
        echo "Syntax error: Unknown long option --${opt[0]}" >&2
        #exit 2
        exit $E_USAGE
        ;;
    esac
  break; done
done

#----------------------------------------------------------------------
#  Stop the script if no valid flags were used
#----------------------------------------------------------------------
if [[ ! ${r_flag:-} && ! ${w_flag:-} ]]; then
  echo "Please choose one of the 2 options: -r/--read or -w/--write)."
  exit $E_USAGE
fi

#----------------------------------------------------------------------
#  Stop the script if both flags were used
#----------------------------------------------------------------------
if [[ ${r_flag:-} && ${w_flag:-} ]]; then
  echo "The -r/--read and -w/--write flags are mutually exclusive" >&2
  echo "You can either run the script in read mode or in write mode." >&2
  exit $E_USAGE
fi

#----------------------------------------------------------------------
#  Extract the directory path and the file size
#----------------------------------------------------------------------
if [[ ! ${b_flag:-} ]]; then
  #echo "First non-option-argument (if exists): ${!OPTIND-}"
  if [[ "${!OPTIND-}" ]]; then    # check if there are any non-option arguments
    shift "$((OPTIND-1))"    # remove all the options that were parsed by getopts
#    echo "\"\$#\":$#"    # show the number of arguments
#    echo "\"\$0\":$0"    # show the script path
#    echo "\"\$1\":$1"    # show the first argument
#    echo "\"\$2\":$2"    # show the second argument
#    echo "\"\$3\":$3"    # show the third argument
    echo "The directory path was specified: ${1}"
    path="${1}"
    temporary_file="$path/dd-bs-benchmark.tmp"

    # Abort the benchmark if the temporary file exists
    if [[ -e $temporary_file ]]; then
      echo "The folder $path already contains a file called dd-bs-benchmark.tmp,"
      echo "please remove it or provide another folder."
      exit $E_USAGE
    fi

    if [[ "${2:-}" ]]; then
      echo "The file size was specified: ${2}"
      temporary_file_size="${2}"
      validate_number "$temporary_file_size"    # validate the provided number
      echo "The file will be $temporary_file_size bytes large."
    else
      echo "The file size was not specified."
      echo "The default file size of 256 MiB will be used."
      temporary_file_size=268435456
    fi
  else
    echo "Please provide a directory path."
    exit $E_USAGE
  fi
fi

  #---------------------------------------------------------------------------
  #  Extract the block device's path and the size of the data to be benchmaked
  #---------------------------------------------------------------------------
if [[ ${b_flag:-} ]]; then
  if [[ "${!OPTIND-}" ]]; then    # check if there are any non-option arguments
    shift "$((OPTIND-1))"    # remove all the options that were parsed by getopts
    echo "A block device was specified: ${1}"
    block_device="${1}"

    if [[ "${2:-}" ]]; then
      echo "The size was specified: ${2}"
      benchmark_data_size="${2}"
      validate_number "$benchmark_data_size"    # validate the provided number
      echo "The benchmaked data will be $benchmark_data_size bytes large."
    else
      echo "The data size was not specified."
      echo "The default size of 256 MiB will be used."
      benchmark_data_size=268435456
    fi
  else
    echo "Please provide a directory path."
    exit $E_USAGE
  fi
fi

#----------------------------------------------------------------------
#  Extract the minimum and maximum block sizes to be used
#----------------------------------------------------------------------
if [[ ! ${min_block_size:-} ]]; then    # if the -m flag was not used...
  min_block_size=512    # set a default minimum block size
  echo "The default minimum block size of 512 bytes will be used."
fi
if [[ ! ${max_block_size:-} ]]; then    # if the -M flag was not used...
  max_block_size=67108864    # set a default maximum block size of 64 MiB
  echo "The default maximum block size of 67108864 bytes (64 MiB) will be used."
fi

#----------------------------------------------------------------------
#  Check if the directories are valid
#----------------------------------------------------------------------
if [[ ! ${b_flag:-} ]]; then
  validate_directory "$path" "$temporary_file_size"
fi
if [[ ${w_flag:-} && ${t_flag:-} ]]; then
  validate_directory "$temp_dir" "${temporary_file_size:-$benchmark_data_size}"
fi

#----------------------------------------------------------------------
#  Check if the block device path is valid, if applicable
#----------------------------------------------------------------------
if [[ ${b_flag:-} ]]; then
  if [ -e "$block_device" ]; then
    #echo "Test file $block_device exists, using it."
    if [ -b "$block_device" ]; then
      if [[ $(sudo blockdev --getsize64 "$block_device") -gt "$benchmark_data_size" ]]; then
        echo "The block device $block_device is valid"

        read -r -p "The file you have provided is a block device. Do you want to test it? " choice1
        case "$choice1" in
        y|Y|[yY][eE][sS] )
          echo "The test will cause data corruption! Back up your data before going any further."
          read -r -p "Continue? " choice2
          case "$choice2" in
          y|Y|[yY][eE][sS] )
            echo "You answered \"Yes\". Continuing..."
            ;;
          n|N|[nN][oO] )
            echo "You answered \"No\". Aborting..."
            exit 1
            ;;
          * )
            echo "Invalid answer. Aborting..."
            exit 1
            ;;
          esac
          ;;
        n|N|[nN][oO] )
          echo "You answered \"No\". Aborting..."
          exit 1
          ;;
        * )
          echo "Invalid answer. Aborting..."
          exit 1
          ;;
        esac

      else
        echo "The block device $block_device is not large enough to test with"
        echo "$benchmark_data_size bytes. Please use a smaller size."
        exit $E_CANTCREAT
      fi
    else
      echo "The file $block_device is not actually a block device."
      exit $E_USAGE
    fi
  else
    echo "$block_device is missing or you misspelled the path."
    echo "Please check again."
    exit $E_NOINPUT
  fi
fi

#----------------------------------------------------------------------
#  Use a code block where to run any operations that can corrupt data
#----------------------------------------------------------------------
{

  if [[ ${r_flag:-} ]]; then
    # Generate a temporary file with random data
    if [[ ! ${b_flag:-} ]]; then
      echo "Please wait while the file $temporary_file is being written."
    else
      echo "Please wait while the data is written to the block device."
    fi
    bs=65536
    count=$((${temporary_file_size:-$benchmark_data_size} / bs))
    dd bs=$bs conv=fsync count=$count if=/dev/urandom of="${temporary_file:-$block_device}" &> /dev/null

    # Print a header for the list with the read speeds
    # shellcheck disable=SC2059
    printf "$printf_format" 'block size' 'read speed'
  fi

  if [[ ${w_flag:-} ]]; then
    if [[ ${t_flag:-} ]]; then
      # Generate a temporary file with random data in the temporary directory
      bs=65536
      count=$((${temporary_file_size:-$benchmark_data_size} / bs))
      dd bs=$bs conv=fsync count=$count if=/dev/urandom of="$temp_dir/dd-bs-benchmark.tmp" &> /dev/null
    fi

    # Print a header for the list with the write speeds
    # shellcheck disable=SC2059
    printf "$printf_format" 'block size' 'write speed'
  fi

  #--------------------------------------------------------------------
  #  Run benchmarks for multiple block sizes
  #--------------------------------------------------------------------
  for (( bs="$min_block_size"; bs<="$max_block_size"; bs*=2)); do    # benchmark with multiple block sizes

    # Clear the kernel cache to obtain more accurate results
    sync && [[ $EUID -eq 0 ]] && [[ -e /proc/sys/vm/drop_caches ]] && sysctl --quiet vm.drop_caches=3

    if [[ ${r_flag:-} ]]; then
      # Read the temporary file using the $bs block size and send the data to /dev/null
    if [[ ${b_flag:-} ]]; then
        count=$((${temporary_file_size:-$benchmark_data_size} / bs))
        dd_output=$(dd bs="$bs" count=$count if="${temporary_file:-$block_device}" of=/dev/null 2>&1 1>/dev/null)
    else
      dd_output=$(dd bs="$bs" if="${temporary_file:-$block_device}" of=/dev/null 2>&1 1>/dev/null)
    fi

      # Determine the read speed from dd's output and place it in a variable
      read_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

      # Print the current benchmark's read speed
      # shellcheck disable=SC2059
      printf "$printf_format" "$bs" "$read_speed"
    fi

    if [[ ${w_flag:-} ]]; then
      if [[ ${t_flag:-} ]]; then
        # Copy the temporary file from the temporary directory
        dd_output=$(dd bs="$bs" conv=fsync if="$temp_dir/dd-bs-benchmark.tmp" of="${temporary_file:-$block_device}" 2>&1 1>/dev/null)
      else
        # Calculate the number of blocks needed to create the file
        count=$((${temporary_file_size:-$benchmark_data_size} / bs))
        # Create a temporary file using the $bs block size
        dd_output=$(dd bs="$bs" conv=fsync count=$count if=/dev/zero of="${temporary_file:-$block_device}" 2>&1 1>/dev/null)
      fi

      # Determine the write speed from dd's output and place it in a variable
      write_speed=$(grep --only-matching --extended-regexp --ignore-case '[0-9.]+ ([GMk]?B|bytes)/s(ec)?' <<< "$dd_output")

      # Print the current benchmark's write speed
      # shellcheck disable=SC2059
      printf "$printf_format" "$bs" "$write_speed"

      if [[ ! ${b_flag:-} ]]; then
        # Remove the temporary file
        rm "$temporary_file"
      fi

    fi
  done

  if [[ ${r_flag:-} && ! ${b_flag:-} ]]; then
    # Remove the temporary file
    rm "$temporary_file"
  fi

  if [[ ${w_flag:-} && ${t_flag:-} ]]; then
    # Remove the temporary-temporary file
    rm "$temp_dir/dd-bs-benchmark.tmp"
  fi

} || {    # if any command above fails, a fallback code block is ran

  if [[ ${w_flag:-} && ${t_flag:-} ]]; then
    # Remove the temporary-temporary file
    rm "$temp_dir/dd-bs-benchmark.tmp"
  fi

  if [[ ! ${b_flag:-} ]]; then
    # Remove the temporary file
    rm "$temporary_file"
  fi

}
