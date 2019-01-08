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
The old scripts, `dd-ibs-benchmark.sh` and `dd-obs-benchmark.sh` are deprecated and have been superseded by `dd-bs-benchmark.sh`. The last commit containing the two scripts is 320e079ae7968085e7808819e5376f72638e43a3 and the tag v0.1.1.

## License
This software is licensed under the MIT License (MIT Expat License). The full text can be found in the file LICENSE.