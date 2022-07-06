<h1>
    <br>
    jumpcutter-ng
    </br>
</h1>

<h2>A command line tool to remove silent frames from video files.</h2>

### Dependencies
  - Make sure to install these first
    - ffmpeg
    - melt-7
    - ffprobe
    - perl

### Basic Example

    ./jumpcutter.pl -i inputfile.mp4 -o output.mp4

### With Parameters

    ./jumpuctter.pl -i inputfile.mp4 -o output.mp4 --duration=0.75 --padding=0.2
    --threshold=-30dB --vcodec=libx265 --crf 17 --acodec=aac

<h2>Parameters</h2>

    -i --input             Input file, any acceptable format supported by your ffmpeg

    -o --output            Output file, any acceptable format supported by your ffmpeg

    --duration             Duration of silence that triggers truncation in seconds

    --padding              Amount seconds to add back in before and after after the silence

    --threshold            Level of decibels where silence occurs (default -30dB)

    --noise                The amount of noise

    --vcodec               Video codec for the output file. Use --vcodec=list to see options'

    --crf                  CRF Value to give h264, h265 and other compabitble vcodecs.

    --qscale               Q value for mjpeg, mpeg4, libxvid and other compatible vcodecs

    --pix_fmt              Pixel format given to ffmpeg

    --profile              Profile used in some vcodecs

    --preset               Speed of encoding for h264, h265 and other compatible vcodecs

    --acodec               Audio codec to use. (default=libopus)

    --aq                   Q value used by certain some Codecs



### More Examples

Making mov files that will be compatible with Davinci Resolve

    ./jumpcutter.pl -i stream.mp4 -o jumped.mov --vcodec=mpeg4 --qscale=3 --acodec=pcm_s16be --aq=0

    ./jumpcutter.pl -i stream.mp4 -o jumped.mov --vcodec=mjpeg --qscale=2 --acodec=pcm_s16be --aq=0

    ./jumpcutter.pl -i stream.mp4 -o jumped.mov --vcodec=mjpeg --qscale=2 --acodec=libmp3lame --aq=0
