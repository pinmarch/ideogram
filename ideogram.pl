#!/usr/local/bin/perl
# Copyright 2013 Pinmarch
# Project site is https://github.com/pinmarch/ideogram

use strict;
use Getopt::Long;
use GD;
use IO::File;

# load cytoband data
sub loadCytoBand {
 my $datafile = shift || "cytoBand.txt";
 my $data = {};
 my $f = IO::File->new($datafile);
 while (<$f>) {
  # print $_;
  chomp;
  my @cols = split /\t/;
  push @{$data->{$cols[0]}}, \@cols;
 }
 $f->close if $f;
 $data;
}

# returns the max position of some chromosome
sub getMaxPosition {
 my $data = shift;
 my @chrom = @_;
 my @poslist;
 if (!@chrom) {
  @poslist = map { getMaxPosition($data, $_) } keys %{$data};
 } else {
  @poslist = map { ($_->[1], $_->[2]) } map { @{$data->{$_}} } @chrom;
 }
 pop @{[ sort { $a <=> $b } @poslist ]};
}

sub widthConv {
 my $w = shift;
 my $f = shift;
 $w > 0 ? ($f ? sqrt $w : $w) : 0;
}

my %cmdopts = ();
GetOptions(\%cmdopts, "width=i", "height=i", "chroms=s@", "fill", "output=s");

my %chroms = map { ("chr".(1..22, "X", "Y")[$_], $_) } (0..23);
my @tchroms = $cmdopts{chroms} ?
              (grep { exists $chroms{$_} } map { s/chr/chr/i; $_ }
               (split /,/, join(",", @{$cmdopts{chroms}}))) :
              (sort { $chroms{$a} <=> $chroms{$b} } (keys %chroms));

my $cytoband = loadCytoBand();
my $im_width = $cmdopts{width} > 0 ? $cmdopts{width} : 700;
my $im_height = $cmdopts{height} > 0 ? $cmdopts{height} : 40;
my $img = new GD::Image($im_width, $im_height * @tchroms, 1);
my $img_arc = new GD::Image(10, $im_height, 1);

my $trans = $img->colorAllocate(244, 0, 244);
my $white = $img->colorAllocate(255, 255, 255);
my $black = $img->colorAllocate(0, 0, 0);
my %colors = (
 gneg => $white,
 gvar => $img->colorAllocate(228, 200, 200),
 stalk => $img->colorAllocate(184, 184, 228),
 acen => $img->colorAllocate(228, 144, 144),
 gpos25 => $img->colorAllocate(216, 216, 216),
 gpos50 => $img->colorAllocate(144, 144, 144),
 gpos75 => $img->colorAllocate(96, 96, 96),
 gpos100 => $img->colorAllocate(30, 30, 30),
);
$img->transparent($trans);
$img->fill(1, 1, $trans);

$img_arc->transparent($white);
$img_arc->fill(1, 1, $trans);
$img_arc->filledEllipse(5, $im_height / 2, 10, $im_height, $white);
$img_arc->ellipse(5, $im_height / 2, 10, $im_height, $black);

my $shadefile = "shade_grad.png";
my $shade_imgorg = GD::Image->newFromPng($shadefile, 1) if -e $shadefile;


my $mpw = getMaxPosition($cytoband, @tchroms);
my $lineindex = 0;
foreach my $c (@tchroms) {
 my $mp = getMaxPosition($cytoband, $c);
 $mpw = $mp if $cmdopts{fill};
 my $acen_x = undef;

 my $offset_top = $lineindex * $im_height;
 my $offset_btm = ($lineindex + 1) * $im_height - 1;

 foreach my $l (@{$cytoband->{$c}}) {
  my $x1 = $im_width * widthConv($l->[1] / $mpw);
  my $x2 = $im_width * widthConv($l->[2] / $mpw) - 1;
  $img->filledRectangle($x1, $offset_top, $x2, $offset_btm, $colors{$l->[4]});
  $acen_x = $x2 if (!$acen_x && $l->[4] eq "acen");
 }

 # drawing shade (overlay)
 if ($shade_imgorg) {
  my @ssize = $shade_imgorg->getBounds();
  my $l = ${$cytoband->{$c}}[-1];
  my $w = $im_width * widthConv($l->[2] / $mpw);
  $img->copyResampled($shade_imgorg, 0, $offset_top + $im_height / 3,
                      0, 0, $w, $im_height * 2 / 3, $ssize[0], $ssize[1]);
 }

 # drawing border
 $img->rectangle(0, $offset_top,
                 $im_width * widthConv($mp / $mpw) - 1, $offset_btm, $black);

 # drawing rounded rectangles
 $img->copyMerge($img_arc, 0, $offset_top, 0, 0, 5, $im_height, 100);
 $img->copyMerge($img_arc, $im_width * widthConv($mp / $mpw) - 5,
                 $offset_top, 5, 0, 5, $im_height, 100);
 $img->copyMerge($img_arc, $acen_x, $offset_top, 0, 0, 5, $im_height, 100);
 $img->copyMerge($img_arc, $acen_x - 5, $offset_top, 5, 0, 5, $im_height, 100);

 $lineindex++;
}


my $outfile = $cmdopts{output} || undef;
if ($outfile) {
 $outfile = IO::File->new(">$cmdopts{output}") || die "Output $outfile cannot open.\n";
}
my $output = $outfile || *STDOUT;
binmode $output;
print $output $img->png;
$output->close if $output != *STDOUT;

exit;

