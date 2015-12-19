#!/usr/bin/perl -w
use strict;
use JSON;

my $file = 'data/2015-12-13-21-05-18.json';

open(IN, $file) || die "$file: failed to open";
my $txt = <IN>;
close(IN);

sub rdump {
        my ($prefix, $o) = @_;

        my $type = ref($o);

        print "$prefix$type\n" if $type ne '';
        $prefix .= "  |";

        if ($type eq 'HASH') {

                for my $k (keys %{$o}) {
                        print "$prefix- ", "$k", "\n";
                        rdump("$prefix", $o->{$k});
                }

        } elsif ($type eq 'ARRAY') {

                for my $k (keys @{$o}) {
                        print "$prefix- ", $k, "\n";
                        rdump("$prefix", $o->[$k]);
                }

        } elsif ($type eq '') {

                if ($o =~ m/^[\[{]/) {

                        my $n = decode_json $o;

                        rdump("$prefix", $n);

                } else {

                        print "$prefix- ", $o, "\n";

                }
        }
}

my $j0 = decode_json $txt;

foreach my $k0 (keys %{$j0}) {

        print $k0, "\n";

        rdump("", $j0->{$k0});
}
