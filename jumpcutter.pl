#!/usr/bin/perl
use warnings;
use strict;
use IPC::Open3;
use Symbol 'gensym';
use Data::Dumper;
use POSIX;

use Getopt::Long;



my $file = "input.mp4";
my $outfile = "output.mp4";
my $dbThreshold = '-30dB';
my $duration = '1.000';
my $noise = '0.005';
my $padding = 0.150;
my $threads = 2;
my $vcodec = "libx264";
my $acodec = "libopus";
my $aq = "";
my $crf = 17;
my $preset = "ultrafast";
my $profile = "";
my $pix_fmt = "";
my $qscale = "";

GetOptions('input=s' => \$file,
           'output=s' => \$outfile,
           'threshold=s' => \$dbThreshold,
           'duration=f' => \$duration,
           'noise=f' => \$noise,
           'padding=f' => \$padding,
           'threads=i' => \$threads,
           'crf=i' => \$crf,
           'acodec=s' => \$acodec,
           'aq=i' => \$aq,
           'vcodec=s' => \$vcodec,
           'preset=s' => \$preset,
           'profile=s' => \$profile,
           'pix_fmt=s' => \$pix_fmt,
           'qscale=i' => \$qscale
          ) || die;

print "input = $file\n";
print "output = $outfile\n";
print "threshold = $dbThreshold\n";
print "duration = $duration\n";
print "noise = $noise\n";
print "padding = $padding\n";
print "threads = $threads\n";
print "acodec = $acodec\n";
print "aq = $aq\n";
print "vcodec = $vcodec\n";
print "profile = $profile\n";
print "pix_fmt = $pix_fmt\n";
print "crf = $crf\n";
print "preset = $preset\n";
print "qscale = $qscale\n";

my $probe = qq[ ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 ];
$probe .= qq[ -show_entries stream=width,height,r_frame_rate "$file" ];

my $probe_output = qx($probe);

my @lines = split /\r?\n/, $probe_output;

my $frame_ratio = $lines[2];
my $frame_rate_num;
my $frame_rate_den;
my $framerate;
if ($frame_ratio =~ m[(\d+)/(\d+)])
{
  $frame_rate_num = $1;
  $frame_rate_den = $2;
  $framerate = $frame_rate_num / $frame_rate_den;
}
else
{
  die "Unable to calculate frame rate did you specify the right input file and have ffprobe installed?";
}

my $width = $lines[0];
my $height = $lines[1];
print "framerate = $framerate\n";
print "dimensions = ${width}x${height}\n";

my $mlt_file = "${outfile}.mlt";
my $segmentStart = 0.0;

my $command = qq[ffmpeg -i "$file" -af silencedetect=n=$dbThreshold:d=$duration:noise=$noise -f null -];
print "$command\n";
my $pid = open3(my $ff_in, my $ff_out, my $ff_stderr = gensym, $command);

open my $mlt, ">$mlt_file" || die "Unable to open '$mlt_file'\n";

print $mlt qq[
<mlt>
  <profile frame_rate_num="$frame_rate_num" frame_rate_den="$frame_rate_den" width="$width" height="$height" />
  <producer id="producer0">
    <property name="resource">$file</property>
  </producer>
  <producer id="producer1" in="0" out=":1.0">
    <property name="length">15000</property>
    <property name="eof">pause</property>
    <property name="resource">red</property>
    <property name="aspect_ratio">1.06667</property>
    <property name="mlt_service">colour</property>
  </producer>

  <playlist id="playlist0">
];

my $last_SegmentStart = -1;
my $last_SegmentEnd = -1;
my $count = 1;
while (my $line = <$ff_stderr>)
{
  chomp $line;

  if ($line =~ m/silence_start: ([0-9\.]+)/)
  {
    my $start = $1;
    my $segmentEnd = $start + $padding;
    if ($segmentStart > 0)
    {
      $segmentStart = $segmentStart - $padding;
    }

    if ($segmentEnd <= $segmentStart) { die "segmentEnd ($segmentEnd) <= segmentStart ($segmentStart)"; }

    if ($segmentEnd <= $last_SegmentEnd) { die "segmentEnd ($segmentEnd) <= last_SegmentEnd ($last_SegmentEnd)"; }
    if ($segmentStart <= $last_SegmentStart) { die "segmentStart ($segmentStart) <= last_SegmentStart ($last_SegmentStart)"; }
    $last_SegmentEnd = $segmentEnd;
    $last_SegmentStart = $segmentStart;

    my $segStartHours = floor($segmentStart / 3600);
    my $segStartMinutes = floor(($segmentStart % 3600) / 60);
    my $segStartSeconds = $segmentStart % 60 + ($segmentStart - int($segmentStart));
    my $segStartString = sprintf "%02d:%02d:%.03f", $segStartHours,$segStartMinutes,$segStartSeconds;

    my $segEndHours = floor($segmentEnd / 3600);
    my $segEndMinutes = floor(($segmentEnd % 3600) / 60);
    my $segEndSeconds = $segmentEnd % 60 + ($segmentEnd - int($segmentEnd));
    my $segEndString = sprintf "%02d:%02d:%.03f", $segEndHours,$segEndMinutes,$segEndSeconds;

    print $mlt qq[    <entry producer="producer0" in="$segStartString" out="$segEndString" />\n];
    #print $mlt qq[    <entry producer="producer1" in="0" out=":1.0" />\n];

    print "Segment $segStartString - $segEndString\n";
    $count++;
  }

  if ($line =~ m/silence_end: ([0-9\.]+)/)
  {
    $segmentStart = $1;
  }
}
print $mlt qq[  </playlist>\n];
print $mlt qq[</mlt>\n];

my $video_opts = "vcodec=$vcodec ";
if ($profile)
{
  $video_opts .= "profile=$profile ";
}
if ($pix_fmt)
{
  $video_opts .= "pix_fmt=$pix_fmt ";
}
if ($qscale)
{
  $video_opts .= "qscale=$qscale ";
}
$video_opts .= "crf=$crf preset=$preset";


my $audio_opts = "acodec=$acodec ";
if ($aq)
{
  $audio_opts .= "aq=$aq ";
}

$command  = qq[melt-7 -consumer "avformat:$outfile" $video_opts $audio_opts ];
#$command .= " frame_rate_den=$frame_rate_den frame_rate_num=$frame_rate_num ";
#$command  = "melt-7 -consumer avformat:test.ts f=mpegts vcodec=$vcodec acodec=$acodec crf=$crf preset=$preset ";

$command .= qq["$mlt_file"];
print "$command\n";
system($command);

exit;
