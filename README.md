mp3packer <!-- p,dd { text-align: justify; } h1 { font-variant: small-caps; } img { border: 1px solid #000000; } table \* { text-align: center; } #lorem { display:none; } -->

MP3packer Settings
==================

An MP3 reorganizer
------------------

##### Copyright © 2006-2012 Reed Wilson ("Omion")
ce​di​ll LOREM IPSUM DOLOR SIT AMET a ACCENT gm CONSECTETUR ADIPISICING ELIT ail DO**N**T​ c_**Hmm.. it looks like you don't have CSS. My email will be very hard to decipher**_​SED DO EIUSMOD TEMPOR INCIDIDUNT UT LABORE ET DOLORE MAGNA ALIQUAom

### Abstract

MP3packer is a program which can rearrange the data within an MP3 to fulfill specific goals. By default, the program generates the smallest MP3 possible (with the least padding). However, many people also use it to turn VBR files into CBR for use with players which don't support VBR.

### License

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. Please see [gpl.txt](gpl.txt) for more details. Source code for this program should be available from the same place as the compiled version.

### Usage

`mp3packer` \[ `options` \] `in.mp3` \[ `out` \]  
Processes `in.mp3` according to `options` and saves the output to `out`. If `out` is a directory, mp3packer will keep the same name as `in` but in the `out` directory. If `out` is not given, the `-a` string will be appended to the file name (see below).

`mp3packer` \[ `options` \] `inDir` \[ `outDir` \]  
Processes all files ending in ".mp3" in the directory `inDir`. This is not recursive. If `outDir` is given, all output files will have the same name in the `outDir` directory. If `outDir` is not given, the files will have the `-a` string appended to them, and will stay in `inDir`.

`options`, if specified, may be any of the following:

`-b #`

Minimum bitrate allowed for output. Defaults to 0, which means all frame sizes are allowed. If the number given is a valid bitrate, the minimum frame size will be "dithered" between padded and unpadded frames, depending on standard CBR rules. If the bitrate given is one more than a valid bitrate, all frames will be padded. Anything larger than the maximum bitrate will be clamped to a padded maximum-bitrate frame. All other bitrates will round up to the next higher unpadded frame.  
For example, `-b 129` will result in the smallest allowed frame size being a padded 128kbps frame. `-b 117` will result in the smallest allowed frame size being an _un_padded 128kbps frame. If `-b 128` is used with 44100Hz files, the minimum bitrate will depend on the frame number. Assuming 44100Hz, for 2 frames out of 49 the minimum frame will be unpadded, for the other 47 it will be padded. All bitrates from 114 to 127 will result in the smallest frame being an unpadded 128kbps frame. For further clarifications, see [below](#bswitch).

`-t`

Strip non-MP3 data at the beginning of the file. This will remove some kinds of ID3v2 tags. Use both `-s` and `-t` to remove all tags.

`-s`

Strip non-MP3 data at the end of the file. Using this option will remove most tags and any incomplete last frames from the file.

`-z`

This option makes mp3packer partially decode the audio in the file, optimize the data, then recode it. This method stops decoding before any lossy transformations take place, and therefore _the `-z` switch is still completely lossless_. MP3 files have a number of different methods to compress the data, and most encoders only choose between a few of them. The `-z` switch will do a brute-force search for the most efficient compression setting. This guarantees that each frame is as small as it can get, but it takes longer to repack.

`--workers #`

Set the number of threads to use for `-z` processing. These workers will run in parallel with the rest of the program. 0 is a valid number, and corresponds to synchronous processing. The default is a function of the number of processors/cores the program detects, and will likely change in different versions of the program.

`-a "-vbr"`

Specify the string to append to the file name if no output file name is given. If `mp3packer -a "-food" in.mp3` is given, the output will be named `in-food.mp3`. `"-vbr"` is the default.

`-A`

Don't skip the files in a directory which already have the `-a` string appended. The default prevents files from being processed twice (giving names like filename-vbr-vbr-vbr.mp3), but if you have changed settings to reprocess this may be useful.

`-u`

Updates the input file, and stores a backup to the output file. So after `mp3packer -u process.mp3 backup.mp3`, the file `process.mp3` will contain the packed mp3, and `backup.mp3` will be the same as the original `process.mp3`. Note that if you don't specify an output file or change the `-a` option, the original will have `"-vbr"` appended to it, which may lead to confusion.

`-w`

Silences the whole frame if an error is encountered. By default only the granule with the error (in both channels) is silenced.

`-r`, `-R`

As of 1.16, mp3packer will attempt to minimize the bit reservoir when the `-b` switch is used. The `-r` switch will force minimization all the time, and the `-R` switch will maximize the bit reservoir at every frame (which was the behavior before 1.16). Note that this will not change the size of the files at all, and has little purpose other than occasionally making CBR320 files easier to split.

`--keep-ok` \[ `out` | `both` \]

Specify which files to keep if no errors occur. `out` will only keep the output file and will delete the input file, whereas `both` will keep both files (the default)

`--keep-bad` \[ `in` | `out` | `both` \]

Specify which files to keep if an error occurs. `in` will only leave the input file and will discard the repacked file. `out` does just the opposite. `both` keeps both files (default). Note that buffer under/overflows and sync errors are counted as errors, whereas recompression errors (if using the `-z` switch) are not.

`--copy-time`

The output files' times are copied from the input files. In Windows this preserves the files' creation, modification, and last access times.

`-f`

Force overwriting of the output file, if it exists. When used with the `-u` option, it will force overwriting the backup file.

`--process` \[ `base` | `sse41` \]

Determines which processing algorithm to use for the `-z` switch. The default is SSE4.1 (represented by `"sse41"`) if your computer supports it. There is generally no reason to change the default unless you suspect there is an error in one of the algorithms.

`-i`

Print info about the input file, then exit. The output location, if specified, is ignored. See the info section for more detials.

`--ib`

Similar to `-i`, but print only the minimum CBR bitrate.

`--nice #`

Adjust the priority of the program. Uses a Unix-style range. On Windows the numbers are mapped as follows:

Parameter

<=-16

\-15

\-14

\-13

\-12

\-11

\-10

\-9

\-8

\-7

\-6

\-5

\-4

\-3

\-2

\-1

0

1

2

3

4

5

6

7

8

9

10

11

12

13

14

15

16

17

18

\>=19

Priority

15

14

13

12

11

10

8/9

7

6

5

4

3

2

1

Name

High

Above normal

Normal

Below Normal

Idle

Basically, using `--nice` with **Parameter** will set the Windows priority to **Priority**, which shows up in the task manager as **Name**. The default niceness is 10, which corresponds to a Windows priority of 4, or "Below Normal".

`--debug` \[ `in` | `out` | `huff` | `all` \]

Prints a bunch of debugging info about the files. `--debug in` will report frame statistics about the input file. `--debug out` will report on how the file was processed and written. `--debug huff` will print debug information about the recompression of frames if the `-z` option is given. `--debug all` does all three. It is recommended that you redirect the output to a file, as the information gets quite verbose.

#### Info

By specifying the `-i` option, the program will print data about the input file then exit. No files will be written and the output (if given) will be ignored. Example printout:

\*\*\* "test/APS.mp3"
INFO:
MPEG1 layer 3
21687 frames
44100 Hz
38.281250 frames per second
566.517551 seconds
12514543 bytes in file (176.722405 kbps)
12514126 bytes in MP3 frames (176.716516 kbps) = current bitrate
93784923 bits of payload data (165.546368 kbps)
11732617 bytes of payload data (165.680544 kbps)
76013 bits wasted from partially-full bytes (0.134176 kbps)
12513349 bytes of MP3 data (176.705544 kbps) = minimum bitrate possible
777 bytes of padding (0.010972 kbps)
417 bytes outside MP3 frames (0.005889 kbps)
1 sync error
Bitrate distribution:
32: 9,0
128: 3641,0
160: 7691,0
192: 6700,0
224: 2736,0
256: 785,0
320: 125,0
Largest frame uses 8478 bits = 1060 bytes = 324.548437 kbps
Smallest bitrate for CBR is 256

Using the --ib option will only print the smallest possible CBR bitrate, with no other information.

#### Explanation:

`*** "test/APS.mp3"`

Name of the file processed.

`MPEG1 layer 3   21687 frames   44100 Hz   ``38.281250 frames per second   566.517551 seconds` 

Basic properties of the file. All self-explanatory.

`12514543 bytes in file (176.722405 kbps)`

The number of bytes in the file and the corresponding bitrate. This bitrate includes tags and non-MP3 data which can be stripped out using the `-s` and `-t` options.

`12514126 bytes in MP3 frames (176.716516 kbps) = current bitrate`

The number of bytes currently in MP3 frames. This does not count tags and broken frames. This is the current bitrate of the file.

`93784923 bits of payload data (165.546368 kbps)`

The bits of payload data. This ignores padding, headers, side-info, and tags.

`11732617 bytes of payload data (165.680544 kbps)`

The bytes of payload data. This is not a direct result of the previous line, and in fact is generally going to be a higher bitrate than the previous line due to partially-full bytes.

`76013 bits wasted from partially-full bytes (0.134176 kbps)`

The number of bits wasted from partially-full bytes. The bitrate here is the difference between the previous two lines. Nothing can be done to "repack" this wasted data.

`12513349 bytes of MP3 data (176.705544 kbps) = minimum bitrate possible`

The amount of payload data plus headers and side-info. Assuming that mp3packer completely gets rid of all padding and non-mp3 data, this is the smallest bitrate that can be achieved.

`777 bytes of padding (0.010972 kbps)`

The total amount of padding in the file. This is the main thing that mp3packer tries to get rid of.

`417 bytes outside MP3 frames (0.005889 kbps)`

The amount of padding and tags outside of MP3 frames. By default, everything before the first frame and after the last frame is kept, but all non-MP3 data between frames will be discarded.

`1 sync error`

The number of times when a frame is not found directly after the previous frame.

`32: 9,0   128: 3641,0   160: 7691,0   192: 6700,0   224: 2736,0   256: 785,0   320: 125,0`

The bitrate distribution of the file. Only the bitrates that actually appear in the file wil be listed. The two numbers given per line are the unpadded,padded frames. In the above example, there are nine unpadded 32kbps frames, and no padded frames of any bitrate.

`Largest frame uses 8478 bits = 1060 bytes = 324.548437 kbps`

Information about the frame with the largest amount of data. If the bit reservoir were not used, this would be the smallest CBR bitrate possible.

`Smallest bitrate for CBR is 256`

The smallest value for the -b option that will result in a CBR file. This number is generally much less than the previous line due to the bit reservoir. It is, however, generally much more than the average bitrate because of limitations on the bit reservoir. Note that using the `-z` switch may reduce the minimum, but will never increase it.

### How it works:

In normal operation, mp3packer will iterate over the input frames and choose the smallest frame size which can store all the data needed. It will therefore minimize the file size by ensuring that the frames are as the smallest possible. This is actually somewhat difficult, as the frame size depends on how much of the current frame's data can be stored in previous frames, and how much space in the current frame is necessary to store data from following frames.

#### The -z switch:

Whereas the default operation is to choose the minimum frame size to fit the data, using the `-z` switch will also minimize the data size. This is completely lossless as long as the input file has no errors, and is equivalent to decompressing a ZIP file and recompressing with a more aggressive setting. It attempts to minimize the data by doing a brute-force search for the optimal parameters, so it takes much longer than it would normally.

#### The -b switch:

Setting the `-b` switch will set the minimum bitrate for each frame. Using this switch will make more room in small frames for other frames' data, so it will also generally reduce the maximum bitrate as well. There is no direct control over the maximum bitrate, since there may simply be too much data to fit into a smaller frame. The exact format of the parameter is a bit odd: if the bitrate given is a valid frame bitrate, the minimum bitrate is dithered between padded and unpadded frames. If the bitrate is one more than a valid frame bitrate, then the minimum is a padded frame of bitrate one less than the given. Anything else is rounded up to the next highest unpadded bitrate. An example table may be simpler to follow, assuming a 32, 44.1, or 48kHz file:

Parameter given to -b:

Resultant minimum frame size:

0-31

unpadded 32kbps

32

exactly 32kbps

33

padded 32kbps

34-39

unpadded 40kbps

40

exactly 40kbps

41

padded 40kbps

42-47

unpadded 48kbps

48

exactly 48kbps

49

padded 48kbps

50-63

unpadded 64kbps

64

exactly 64kbps

65

padded 64kbps

...

...

The "exact" bitrates are as follows:

32000, 44100, or 48000kHz:

32

40

48

56

64

80

96

112

128

160

192

224

256

320

Everything else:

8

16

24

32

40

48

56

64

80

96

112

128

144

160

If an exact bitrate is given, the minimum bitrate will switch between unpadded and padded frames as needed in order to achieve exactly that bitrate. For 8, 12, 16, 24, 32, and 48kHz files, this uses all unpadded frames.

#### The -r and -R switches:

After mp3packer has chosen an output bitrate for a given frame, there is generally a range of positions to put the actual data. The data can be packed as much as possible into the previous frame, or it can be set to fill up the current frame as much as possible.

The default is to pack as far behind as possible if the `-b` switch is not given, since there is usually no problem filling up the frames. If a minimum bitrate is specified then the frames are pushed as far up as possible without affecting any of the following frames.

The `-r` switch will attempt to always push data as far up as possible, even if a minimum bitrate is not specified. Conversely, the `-R` switch will push the data into previous frames as possible (note that this was the default behavior before 1.16).

Note that these options do not affect file size or compatibility at all. It will only change the internal layout of the data in the frames.

### Changelog:

2.04 (2012-08-31)

Fixed a bug where `--copy-time` did not work with Unicode filenames.

2.03 (2012-08-05)

Fixed a bug with the 32-bit build giving errors with files larger than 256MiB. It will still not work with files 1GiB or larger, but the warning is more user-friendly.

2.02 (2012-07-28)

Multi-threading is more efficient. `-z` processing can go 2-3x faster than 2.01 with quad-core processors.  
Check the input frames' CRC if they have it.

2.01 (2012-07-15)

Removed a debug line causing a file named pipe.bin to be created.

2.00 (2012-07-14)

Re-made the `-z` processing to be multi-threaded and use SSE if available.

1.26 (2012-07-11)

Fixed a problem where deleting a file would fail in many cases.  
Fixed some Windows terminal corruption related to printing Unicode filenames (Unicode names are even less likely to print correctly in the terminal)

1.25 (2012-02-24)

Support Unicode files and directories (names may not print correctly)  
Made re-synchronization faster  
Simple stereo and joint stereo frames are now considered equivalent for re-synchronization

1.24 (2012-02-16)

Give warning messages in more cases where the output file may not exactly match the input file.  
Change the handling of invalid frames to be more like Foobar2000.

1.23 (2011-08-14)

Fixed an invalid buffer operation related to the bug fixed in 1.22.

1.22 (2011-06-26)

Fixed a rare bug that caused mp3packer to quit with certain corrupted files.  
Minor changes to `-z` to deal with overflows better  
Display recompression (`-z`) errors, and make all errors displays a bit more user-friendly.

1.21 (2010-08-06)

Frame queues are more efficient. Some files would take a very large amount of CPU time with some options in 1.16-1.20. Output files should be identical to 1.20 except for the padding bytes.

1.20 (2008-05-06)

Made the frame checker more lenient. It now will accept changes in CRC, copyright, and emphasis per frame.

1.19 (2007-09-29)

Added time information to the sync error and buffer error messages to indicate the approximate location of the error. Error times are only valid relative to the output file, and may be off by up to 0.1 seconds.

1.18 (2007-06-05)

Supports the `--nice` option, for changing the program's priority.  
Minor bug fixes to the initial frame detection algorithm.

1.17 (2007-05-23)

Multiple improvements to the `-z` switch. It now goes ~40% slower, but manages a bit of extra compression. This change is most apparent with low-bitrate encodes.  
Fixed the `-i` switch. No longer prints a bunch of garbage for every frame, and the number of bits wasted is no longer negative.

1.16-169 (2007-05-09)

Major rewrite of the frame queue. Should be easier to maintain and makes more sense to read, but doesn't mean anything to the end user.  
Added the `-r` and `-R` options to control bit reservior minimization.  
`-z` now works with MPEG-2 files.  
Patched a problem with `-z` outputting larger frames than the input.  
The program will only resync if it finds 3 valid frames in a row.  
Deleting the first granule in an invalid frame now works correctly.

1.15-162 (2007-02-18)

Don't use consistant "original" bit as a requirement for valid frames.

1.14-159 (2007-01-20)

Worded some of the warnings better.  
Match up the number of buffer warnings with the number displayed at the end of repacking.

1.13-145 (2006-10-17)

Throw out VBRI frames from the input file. They aren't actually audio data and the information wasn't saved anyway, so there's no reason to keep them.

1.12-143 (2006-10-04)

Suppressed many warnings from the `-z` switch when the errors had no effect on anything.

1.11-141 (2006-09-30)

Fixed an array overflow when using `-z` which showed up mainly for high-bitrate iTunes encodes.

1.10-139 (2006-09-28)

Re-implemented full-directory packing and support for deleting files on a successful repacking. Included the `-z` option for brute-force Huffman table searching.

1.09-134 (2006-08-06)

Now prints out the the number of sync errors when using the `-i` mode, and prints sync/buffer errors if they occur in normal mode.

1.08-133 (2006-07-27)

Added the `-w` switch to throw out entire frames if only one granule has a buffer error. This mirrors what Foobar does upon encountering a broken frame.

1.07-132 (2006-07-22)

Fixed the frame detection to ignore all the settings found in the XING frame's header.  
Added support for files with only offset information but nothing else.

1.06-130 (2006-07-20)

Fixed a bizarre bug that occured when an XING tag has neither CRC nor encoder info, but the other frames have CRCs.

1.05-128 (2006-07-16)

Fixed another problem with a frame referencing data before the beginning of the file. All reservoir-related exceptions should now be non-fatal.  
Added the `-u` switch to update the original file and keep a backup of the old file.

1.04-126 (2006-06-25)

Fixed an error when a frame attempts to access data from the following frame(s).  
Tweaked the silent-frame detection.

1.03-123 (2006-05-25)

Remove all data from frames which have been determined to be silent.

1.02-112 (2006-04-20)

Fixed the previous fix.  
Fixed a problem when an XING tag was parsed as a LAME tag.

1.01-110 (2006-04-13)

Fixed a crash when the first frame references data from before the beginning of the file.

1.00-106 (2006-03-15)

First release of the OCaml version.