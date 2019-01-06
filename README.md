# dd-bs-benchmark

This is a project aiming to find the average read and write transfer speeds a device is able to achieve by running `dd` with various block sizes. Currently, block sizes from 512 bytes to 64 MiB are used (512, 1024, 2048, ... 65536, ... 67108864). That's 18 tests. It will help you find the optimal input and output block sizes to use with the respective device to achieve high transfer speeds.

### How to use
The script accepts a flag, a folder path and a number.
```
./dd-bs-benchmark.sh -r /path/to/directory [number]
./dd-bs-benchmark.sh -w /path/to/directory [number]
```
The flag as well as the folder path are mandatory. The folder path must point to one on the drive to be benchmarked. The last argument, the number is optional and it must be the size in bytes of the temporary file that will be created in the folder. It can only be a natural number a.k.a. positive integer a.k.a. non-negative integer in the form [0-9], like 1234 but not +1234 or -1234 or 12.34 nor 1,234. If no number is provided, 268435456 will be used by default (256 MiB). It should be enough for a slow device, like a memory card or a flash drive, which are relatively slow but if you want to benchmark a faster device, like a Hard Drive or worse, a Solid State Drive you would need to provide a larger file size because 256 MiB would be read or written in less than a second, which will give unreliable results. In read mode (-r), it will create the file just once and read it 18 times. __**Warning:**__ in write mode (-w), the script will create *the* file __**18**__ times. Hold that into consideration before benchmarking flash drives, SSDs or other flash memory devices and use files as small as possible.

#### Examples:
```
./dd-bs-benchmark.sh -r /media/user/External_storage 536870912
```
The command above will create a 512 MiB file with `dd` in the directory /media/user/External_storage then read it back repeatedly with `dd` using different block sizes and print the read speeds obtained. If no size were specified, the script would create a file of the default size which is 256 MiB.

```
./dd-bs-benchmark.sh -w /media/user/External_storage 536870912
```
The command above will create a 512 MiB file with `dd` using a block size of 512 bytes in the directory /media/user/External_storage and print the write speed obtained then delete the file. It would then create another file using a block size of 1024 bytes, then one with 2 kiB and so on. If no size were specified, the script would create 256 MiB files.


## WARNING!
The following lines are about the old scripts, `dd-ibs-benchmark.sh` and `dd-obs-benchmark.sh`, which are as of now considered deprecated. They have been superseded by `dd-bs-benchmark.sh` which has the same functionality as the former. I already created a branch called "old" containing the last release with the 2 and I will no longer develop them. I will also remove them from the "master" branch soon and keep developing `dd-bs-benchmark.sh` only.

### dd-ibs-benchmark.sh
`dd-ibs-benchmark.sh` creates a file in the given directory of the given size then reads it repeatedly with `dd` using different block sizes and print the read speeds achieved. You can then find the optimal __**input**__ block size(s) to use with the respective drive to achieve a high read speed.

### dd-obs-benchmark.sh
`dd-obs-benchmark.sh` runs `dd` with various __**output**__ block sizes, on each run it creates a file in the directory and prints the average write speed then deletes the file. You can then find the optimal output block size(s) to use with the respective drive to achieve a high write speed. __**Warning:**__ this script will create *the* file 18 times. Hold that into consideration before benchmarking flash drives, SSDs or other flash memory devices.

#### How to use
Both scripts accept 2 arguments: a folder path and a number.
```
./dd-ibs-benchmark.sh /path/to/directory [number]
./dd-obs-benchmark.sh /path/to/directory [number]
```
The folder argument is mandatory and it should be a path to a directory on the drive. The second argument is optional and it is the size in bytes of the temporary file that will be created in the provided folder. It should be a natural number a.k.a. positive integer in the form [0-9], like 1234 but not +1234 or -1234 or 12.34 nor 1,234. If one is not provided, 268435456 bytes (256 MiB) will be used by default. 256 MiB are enough for something like a flash drive or a memory card which are relatively slow but if you want to benchmark a faster Hard Drive or worse, a Solid State Drive you would need to use a larger file because 256 MiB would be read or written in less than a second, which could give unreliable results.

For example:
```
./dd-ibs-benchmark.sh /media/user/External_storage 536870912
```
The command above will create a 512 MiB file with `dd` in /media/user/External_storage then read it back repeatedly with `dd` using different block sizes and print the read speeds recorded. If no size were specified, the script would create a 256 MiB file.

Another example:
```
./dd-obs-benchmark.sh /media/user/External_storage 536870912
```
The command above will create a 512 MiB file with `dd` and a block size of 512 bytes in /media/user/External_storage and print the write speed recorded then delete the file. It would then create a file with a block size of 1024 bytes, then 2 kiB and so on. If no size were specified, the script would create 256 MiB files.

## License
This software is licensed under the MIT License (MIT Expat License). The full text can be found in the file LICENSE.
