#!/usr/bin/perl -w
#
# this is just a quick dumper of the file using Data::Dumper
#

use strict;
use MIME::Base64;
use JSON;
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

                my $activities = $w->{activities};

                for ( my $ai=0; $ai<=$#$activities; $ai++ ) {

                        my $a = $activities->[$ai];

                        print "  #$ai - ",
                                $a->{name},
                                "\n";

                        my $performance = $a->{performance};
                        my $completed = $performance->{completedSets};

                        for ( my $si=0; $si<=$#$completed; $si++ ) {

                                my $s = $completed->[$si];

                                if (defined $s->{weight}) {

                                        my $kg_to_lb = 2.20462;
                                        my $lb = round ($s->{weight} * $kg_to_lb);

                                        print "    ",
                                                "$lb x ",
                                                $s->{reps},
                                                "\n";

                                } elsif (defined $s->{duration}) {

                                        my $sec = $s->{duration} / 1000;

                                        print "    ",
                                                "$sec sec",
                                                "\n";

                                } else {
                                        print "    ",
                                                "BW x ",
                                                $s->{reps},
                                                "\n";
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

        if ($txt =~ m/==$/) {
                $txt = decode_base64($txt);
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