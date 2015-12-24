#!/usr/bin/perl -w
#
# this is just a quick dumper of the file using Data::Dumper
#

use strict;
use MIME::Base64;
use JSON;
use POSIX qw(strftime);

# check if we have access to Math::Round, and if not, use our own
my $have_math_round = (eval "use Math::Round");
sub myround {
        if (not $have_math_round) {
                my ($in) = @_;
                return $in if not defined $in;
                return int($in + 0.5);
        }
        return round($_);
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

my $full_dump = {
        # configuration...

        combine_sets => 1,

        # handlers...

        fws => sub {
                my ($s) = @_ ;
        },
        session => sub {
                my ($s) = @_ ;

                my $i = $s->{session_number};
                my $n = $s->{session}->{name};
                $n = "<improvised>" if not defined $n;

                print "[$i] $n\n";

                my $startTime = $s->{session}->{startTime} / 1000;
                my $endTime = $s->{session}->{endTime} / 1000;

                my $start = strftime "%Y/%m/%d %H:%M:%S", localtime($startTime);
                my $hours = int(($endTime - $startTime) / 36) / 100;

                print "  @ $start + $hours hours\n";
        },
        activity => sub {
                my ($s) = @_ ;

                my $i = $s->{activity_number};
                my $n = $s->{activity}->{name};

                print "  #$i - $n\n";
        },
        set => sub {
                my ($s) = @_ ;
                if ($s->{set_rept}>1) {
                        print "    ", $s->{set_text}, " x ", $s->{set_rept}, "\n";
                } else {
                        print "    ", $s->{set_text}, "\n";
                }
        },
        activity_end => sub {
                my ($s) = @_ ;
        },
        session_end => sub {
                my ($s) = @_ ;
        },
        fws_end => sub {
                my ($s) = @_ ;
        },
};

sub format_set {
        my ($set) = @_;

        my $text;

        if (defined $set->{weight}) {
                my $kg_to_lb = 2.20462;
                my $lb = myround ($set->{weight} * $kg_to_lb);

                $text = "$lb";

                my $reps = $set->{reps};
                $text .= " x $reps" if defined $reps;

        } elsif (defined $set->{duration}) {
                my $sec = $set->{duration} / 1000;
                $text = "$sec sec";

        } else {
                $text = "BW x " . $set->{reps};
        }

        return $text;
}

sub walk_fws {
        my ($h, $fws) = @_;

        # the state object
        my $s = {};

        $h->{fws}($s) if defined $h->{fws};

        for ( $s->{session_number}=0; $s->{session_number}<=$#$fws; $s->{session_number}++ ) {
                $s->{session} = $fws->[$s->{session_number}];

                $h->{session}($s) if defined $h->{session};

                my $activities = $s->{session}->{activities};
                for ( $s->{activity_number}=0; $s->{activity_number}<=$#$activities; $s->{activity_number}++ ) {
                        $s->{activity} = $activities->[$s->{activity_number}];

                        $h->{activity}($s) if defined $h->{activity};

                        if ($h->{combine_sets}) {

                                # prepare for walking the sets
                                $s->{set_text} = "";
                                $s->{set_rept} = 0;

                                my $completedSets = $s->{activity}->{performance}->{completedSets};
                                for ( $s->{set_number}=0; $s->{set_number}<=$#$completedSets; $s->{set_number}++ ) {

                                        $s->{set} = $completedSets->[$s->{set_number}];

                                        my $text = format_set($s->{set});

                                        if ($text eq $s->{set_text}) {

                                                # same work as last time, increment the repeats
                                                $s->{set_rept} ++;

                                        } else {
                                                # diffent workload, so dump the current set first
                                                if ($s->{set_rept}>0) {
                                                        $h->{set}($s) if defined $h->{set};
                                                }

                                                # now start a new set
                                                $s->{set_text} = $text;
                                                $s->{set_rept} = 1;
                                        }
                                }

                                # the last set was not shown yet
                                if ($s->{set_rept}>0) {
                                        $h->{set}($s) if defined $h->{set};
                                }

                                # cleanup
                                undef $s->{set_number};
                                undef $s->{set};
                        } else {
                                $s->{set_rept} = 1;

                                my $completedSets = $s->{activity}->{performance}->{completedSets};
                                for ( $s->{set_number}=0; $s->{set_number}<=$#$completedSets; $s->{set_number}++ ) {

                                        $s->{set} = $completedSets->[$s->{set_number}];

                                        $s->{set_text} = format_set($s->{set});

                                        $h->{set}($s) if defined $h->{set};

                                }
                                undef $s->{set_number};
                                undef $s->{set};

                        }

                        $h->{activity_end}($s) if defined $h->{activity_end};
                }
                undef $s->{activity_number};
                undef $s->{activity};

                $h->{session_end}($s) if defined $h->{session_end};
        }
        undef $s->{session_number};
        undef $s->{session};

        $h->{fws_end}($s) if defined $h->{fws_end};
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

        my $fws = $e->{'fws.json'};

        walk_fws($full_dump, $fws);
}

my $file;

die "$0 <progressionbackup>\n" if $#ARGV < 0;

foreach my $file (@ARGV) {

        summarize_file($file);
}
