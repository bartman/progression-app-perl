#!/usr/bin/perl -w
use strict;
use JSON;

my $file = 'data/2015-12-13-21-05-18.json';

open(IN, $file) || die "$file: failed to open";
my $txt = <IN>;
close(IN);

my $j0 = decode_json $txt;

foreach my $k0 (keys %{$j0}) {

        print $k0, "\n";

        my $j1 = decode_json $j0->{$k0};

        print "\t", ref($j1), "\n";

        if (ref($j1) eq "ARRAY") {
                for my $e (keys @{$j1}) {

                        print "\t\t", $e, "\n";

                }

        } elsif (ref($j1) eq "HASH") {
                for my $k1 (keys %{$j1}) {

                        print "\t\t", $k1, "\n";

                }
        } else {
                print "\t\t", "???", "\n";
        }
}
