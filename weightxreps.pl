#!/usr/bin/perl -w
#
# this script generates summary of Progression workouts in format
# compatible with weightxreps.net website.
#

use strict;
use MIME::Base64;
use JSON;
use POSIX qw(strftime);
use Getopt::Long qw(:config auto_help); # generate --help from POD
use Pod::Usage qw(pod2usage);
use Date::Parse;

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

sub activity_name_map {
        my ($n) = @_;
        if ($n =~ m/^Barbell Squat/) {
                return '#squat';
        } elsif ($n =~ m/^Barbell Bench Press/) {
                return '#bench-press';
        } elsif ($n =~ m/^Barbell Shoulder Press/) {
                return '#OHP';
        } elsif ($n =~ m/^Bent-Over Barbell Row/) {
                return '#barbell-row';
        } elsif ($n =~ m/^Barbell Deadlift/) {
                return '#deadlift';
        } elsif ($n =~ m/^Triceps Dip/) {
                return '#dips';
        }
        $n =~ tr/[A-Z]/[a-z]/;
        $n =~ s/ +/-/g;
        $n =~ s/[^a-z-]//g;
        $n =~ s/-warmup$//;
        return "#$n";
};

my $full_dump = {
        # configuration...

        combine_sets => 1,
        convert_to_lb => 1,

        # handlers...

        fws => sub {
                my ($h,$s) = @_ ;
        },
        session => sub {
                my ($h,$s) = @_ ;

                my $i = $s->{session_number};
                my $n = $s->{session}->{name};
                $n = "<improvised>" if not defined $n;


                my $startTime = $s->{session}->{startTime} / 1000;
                my $endTime = $s->{session}->{endTime} / 1000;

                my $start = strftime "%Y/%m/%d %H:%M:%S", localtime($startTime);
                my $hours = int(($endTime - $startTime) / 36) / 100;

                printf "%-5s  %-30s    @ %s\n",
                        "[$i]",
                        $n,
                        "$start + $hours hours";
        },
        activity => sub {
                my ($h,$s) = @_ ;

                #my $i = $s->{activity_number};
                my $n = $s->{activity}->{name};

                $n = activity_name_map($n);

                return if ($s->{last_activity_printed} or "") eq $n;
                $s->{last_activity_printed} = $n;

                print "$n\n";
        },
        format_set => sub {
                my ($h,$s) = @_;
                my $set = $s->{set};

                my $text;

                if (defined $set->{weight}) {
                        my $kg_to_lb = 2.20462;
                        my $weight = $set->{weight};

                        $weight *= $kg_to_lb if $h->{convert_to_lb};

                        my $lb = myround ($weight);

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
        },
        set => sub {
                my ($h,$s) = @_ ;
                my $text = $s->{set_text};
                $text .= " x " . $s->{set_rept} if $s->{set_rept} > 1;
                print "$text\n";
        },
        activity_end => sub {
                my ($h,$s) = @_ ;
        },
        session_end => sub {
                my ($h,$s) = @_ ;
        },
        fws_end => sub {
                my ($h,$s) = @_ ;
        },
};

sub walk_fws {
        my ($h, $fws) = @_;

        # the state object
        my $s = {};

        $h->{fws}($h,$s) if defined $h->{fws};

        #for ( $s->{session_number}=0; $s->{session_number}<=$#$fws; $s->{session_number}++ ) {
        for ( $s->{session_number}=$#$fws; $s->{session_number}>=0; $s->{session_number}-- ) {
                $s->{session} = $fws->[$s->{session_number}];

                if (defined $h->{session_filter}) {
                        next if not $h->{session_filter}($h,$s);
                }

                $h->{session}($h,$s) if defined $h->{session};

                my $activities = $s->{session}->{activities};
                for ( $s->{activity_number}=0; $s->{activity_number}<=$#$activities; $s->{activity_number}++ ) {
                        $s->{activity} = $activities->[$s->{activity_number}];

                        if (defined $h->{activity_filter}) {
                                next if not $h->{activity_filter}($h,$s);
                        }

                        $h->{activity}($h,$s) if defined $h->{activity};

                        if ($h->{combine_sets}) {

                                # prepare for walking the sets
                                $s->{set_text} = "";
                                $s->{set_rept} = 0;

                                my $completedSets = $s->{activity}->{performance}->{completedSets};
                                for ( $s->{set_number}=0; $s->{set_number}<=$#$completedSets; $s->{set_number}++ ) {

                                        $s->{set} = $completedSets->[$s->{set_number}];

                                        my $text = $h->{format_set}($h,$s);

                                        if ($text eq $s->{set_text}) {

                                                # same work as last time, increment the repeats
                                                $s->{set_rept} ++;

                                        } else {
                                                # diffent workload, so dump the current set first
                                                if ($s->{set_rept}>0) {
                                                        $h->{set}($h,$s) if defined $h->{set};
                                                }

                                                # now start a new set
                                                $s->{set_text} = $text;
                                                $s->{set_rept} = 1;
                                        }
                                }

                                # the last set was not shown yet
                                if ($s->{set_rept}>0) {
                                        $h->{set}($h,$s) if defined $h->{set};
                                }

                                # cleanup
                                undef $s->{set_number};
                                undef $s->{set};
                        } else {
                                $s->{set_rept} = 1;

                                my $completedSets = $s->{activity}->{performance}->{completedSets};
                                for ( $s->{set_number}=0; $s->{set_number}<=$#$completedSets; $s->{set_number}++ ) {

                                        $s->{set} = $completedSets->[$s->{set_number}];

                                        $s->{set_text} = $h->{format_set}($h,$s);

                                        $h->{set}($h,$s) if defined $h->{set};

                                }
                                undef $s->{set_number};
                                undef $s->{set};

                        }

                        $h->{activity_end}($h,$s) if defined $h->{activity_end};
                }
                undef $s->{activity_number};
                undef $s->{activity};

                $h->{session_end}($h,$s) if defined $h->{session_end};
        }
        undef $s->{session_number};
        undef $s->{session};

        $h->{fws_end}($h,$s) if defined $h->{fws_end};
}


sub summarize_file {
        my ($handlers, $file) = @_;

        open(IN, $file) || die "$file: failed to open";
        my $txt = <IN>;
        close(IN);

        if (my $dec = decode_base64($txt)) {
                $txt = $dec;
        }

        my $j = decode_json($txt);

        my $e = expand_nested($j);

        my $fws = $e->{'fws.json'};

        walk_fws($handlers, $fws);
}

# ------------------------------------------------------------------------

my $progname = $0;
$progname =~ s,.*/,,g;

my $usage = "$progname [-h | -help] [-d <YYYY/MM/DD> | -s <number>] -i <progressionbackup>";
die "$usage\n" if $#ARGV < 0;

my $arg_file;
my $arg_date;
my $arg_session;

# start with default handlers...
my $handlers = $full_dump;

GetOptions (
        "i|input=s"    => \$arg_file,
        "d|date=s"     => \$arg_date,
        "s|session=i"  => \$arg_session,
        "all"          => sub { $handlers->{combine_sets} = 0; },
        "kg"           => sub { $handlers->{convert_to_lb} = 0; },
        "man"          => sub { pod2usage(-verbose => 2, -exitval => 0); },
) or die("Error in command line arguments\n");

if (not defined $arg_file) {
        die "$progname: input file is requred, see --help\n";
}

if (defined $arg_date and defined $arg_session) {
        die "$progname: cannot filter on session number and date, see --help\n";
}

if (defined $arg_session) {

        # select the right session based on index

        $handlers->{session_filter} = sub {
                my ($h,$s) = @_;

                $s->{session_number} == $arg_session;
        };

} elsif (defined $arg_date) {

        # select the right session based on date

        my $filter_date = str2time($arg_date)
                or die "$progname: invalid date format, see --help\n";

        my $filter_date_end = $filter_date + (24 * 60 * 60);

        $filter_date *= 1000;
        $filter_date_end *= 1000;

        $handlers->{session_filter} = sub {
                my ($h,$s) = @_;


                $s->{session}->{startTime} <= $filter_date_end
                && $s->{session}->{endTime} >= $filter_date;

        };

} else {

        # don't show activities

        $handlers->{activity_filter} = sub {
                my ($h,$s) = @_;

                0;
        };
}

summarize_file($handlers, $arg_file);

__END__
=head1 NAME

weightxreps.pl - convert Progression App backup files to weightxreps.net

=head1 SYNOPSIS

weightxreps.pl [options]

Options:

  -h -help             brief help message
  -man                 full documentation

  -i -input <file>     progression backup file to read from

  -d -date <date>      date to select for output (YYYY/MM/DD)
  -s -session <num>    session number for output

  --all                list each set individually
  --kg                 generate weights in kg units

=head1 OPTIONS

=over 8

=item B<-usage>

Print the syntax line and exit.

=item B<-help>

Print a brief help message and exit.

=item B<-man>

Print the manual page and exit.

=item B<-input>

Mandatory, identifies which .progressionbackup file read data from.  If no
other options are specified, to restrict or increase output verbosity, then
a brief session summary will be printed.  Each line contains:

  - session number,
  - workout name,
  - date/time started, and
  - duration.

=item B<-date>

Optional, restricts output to the date specified (YYYY/MM/DD), and expands
verbosity to show workout activities.

=item B<-session>

Optional, restricts output to the specified session number, and expands
verbosity to show workout activities.

=item B<-all>

Optional, shows each identical set on its own line.  By default, identical
sets are combined into "<weight> x <reps> x <sets>" format.

=item B<-kg>

Optional, use kg units, instead of lb.

=back

=head1 DESCRIPTION

B<weightxreps.pl> will read a given B<progressionbackup> file and generate
journal entries in B<weightxreps.net> format.

=cut
