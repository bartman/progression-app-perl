#!/usr/bin/perl -w
use strict;
use MIME::Base64;
use JSON;

#my $file = 'data/2015-12-13-21-05-18.json';
my $file = 'data/2015-12-13-21-05-18.progressionbackup';

sub rdump {
        my ($prefix, $n, $o) = @_;

        my $type = ref($o);

        if ($type eq 'HASH') {

                print "$prefix- ", $n, "\n";

                my @keys = sort keys %{$o};
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
