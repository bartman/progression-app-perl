#!/usr/bin/perl -w
#
# this is just a quick dumper of the file using Data::Dumper
#

use strict;
use MIME::Base64;
use JSON;
use POSIX qw(strftime);
# if Math
BEGIN {
        unless (eval "use Math::Round") {
                sub round {
                        my ($in) = @_;
                        return $in if not defined $in;
                        return int($in + 0.5);
                }
        }
}

sub expand_nested {
        my ($in) = @_;

        die "expecting a hash" if ref($in) ne 'HASH';

        my %out = ();

        foreach my $k (sort keys %$in) {
                $out{$k} = decode_json( $in->{$k} );
        }

        return \%out;
}

sub summarize_data {
        my ($d) = @_;

        my $fws = $d->{'fws.json'};

        for ( my $wi=0; $wi<=$#$fws; $wi++ ) {

                my $w = $fws->[$wi];

                print "[$wi] ",
                        $w->{name},
                        "\n";

                my $startTime = $w->{startTime} / 1000;
                my $endTime = $w->{endTime} / 1000;

                my $start = strftime "%Y/%m/%d %H:%M:%S", localtime($startTime);
                my $hours = int(($endTime - $startTime) / 36) / 100;

                print "  @ $start + $hours hours\n";

                my $activities = $w->{activities};

                for ( my $ai=0; $ai<=$#$activities; $ai++ ) {

                        my $a = $activities->[$ai];

                        print "  #$ai - ",
                                $a->{name},
                                "\n";

                        my $performance = $a->{performance};
                        my $completed = $performance->{completedSets};

                        my $last = "";
                        my $rep = 0;

                        for ( my $si=0; $si<=$#$completed; $si++ ) {

                                my $s = $completed->[$si];
                                my $this = "";

                                if (defined $s->{weight}) {
                                        my $kg_to_lb = 2.20462;
                                        my $lb = round ($s->{weight} * $kg_to_lb);
                                        $this = "$lb x " .  $s->{reps};

                                } elsif (defined $s->{duration}) {
                                        my $sec = $s->{duration} / 1000;
                                        $this = "$sec sec";

                                } else {
                                        $this = "BW x " . $s->{reps};
                                }

                                if ($this eq $last) {

                                        $rep ++;

                                } else {
                                        if ($rep>0) {
                                                if ($rep>1) {
                                                        print "    ", $last, " x $rep\n";
                                                } else {
                                                        print "    ", $last, "\n";
                                                }
                                        }

                                        $last = $this;
                                        $rep = 1;
                                }
                        }

                        if ($rep>0) {
                                if ($rep>1) {
                                        print "    ", $last, " x $rep\n";
                                } else {
                                        print "    ", $last, "\n";
                                }
                        }
                }
        }
}

sub summarize_file {
        my ($file) = @_;

        open(IN, $file) || die "$file: failed to open";
        my $txt = <IN>;
        close(IN);

        if (my $dec = decode_base64($txt)) {
                $txt = $dec;
        }

        my $j = decode_json($txt);

        my $e = expand_nested($j);

        summarize_data($e);
}

my $file;

die "$0 <progressionbackup>\n" if $#ARGV < 0;

foreach my $file (@ARGV) {

        summarize_file($file);
}
