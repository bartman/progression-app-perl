#!/usr/bin/perl -w
#
# this program can dump a Progression backup file with niceer nesting and sorting
#

use strict;
use MIME::Base64;
use JSON;


sub specialsort {
        my (@in) = @_;
        my @out = ();

        # list of keys we'd like to have come up first
        my @like = qw{ name id };

        # have we seen them
        my %seen = ();

        # move the in -> out removing the thing we'd like first
        foreach my $k (@in) {

                if ($k ~~ @like) {

                        $seen{$k} = 1;

                } else {

                        push @out, $k;

                }
        }

        # now prefix with the things we'd like first
        my @first = ();
        foreach my $k (@like) {
                push @first, $k if ($seen{$k});
        }

        return (@first,@out);
}

sub rdump {
        my ($prefix, $n, $o) = @_;

        my $type = ref($o);

        if ($type eq 'HASH') {

                print "$prefix- ", $n, "\n";

                my @keys = specialsort keys %{$o};
                while (@keys) {
                        my $k = shift @keys;
                        my $p;
                        if (@keys) { $p = "$prefix  |"; }
                        else       { $p = "$prefix   "; }
                        rdump($p, $k, $o->{$k});
                }

        } elsif ($type eq 'ARRAY') {

                print "$prefix- ", $n, "\n";

                my @keys = sort keys @{$o};

                while (@keys) {
                        my $k = shift @keys;
                        my $p;
                        if (@keys) { $p = "$prefix  |"; }
                        else       { $p = "$prefix   "; }
                        rdump($p, "[$k]", $o->[$k]);
                }

        } elsif ($type eq '') {

                if ($o =~ m/^[\[{]/) {

                        my $j = decode_json $o;

                        rdump("$prefix", $n, $j);

                } else {

                        print "$prefix- $n = $o\n";

                }
        } elsif ($type eq 'JSON::PP::Boolean') {

                print "$prefix  |- ", $o, "\n";

        } else {
                print "$prefix- UNHANDLED TYPE '$type' !!!\n";
        }
}

sub dumpfile {
        my ($file) = @_;

        open(IN, $file) || die "$file: failed to open";
        my $txt = <IN>;
        close(IN);

        if ($txt =~ m/==$/) {
                $txt = decode_base64($txt);
        }

        my $j0 = decode_json $txt;

        foreach my $k0 (sort keys %{$j0}) {

                rdump("", $k0, $j0->{$k0});
        }
}

my $file;

die "$0 <progressionbackup>\n" if $#ARGV < 0;

foreach my $file (@ARGV) {

        dumpfile($file);
}
