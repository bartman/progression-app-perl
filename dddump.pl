#!/usr/bin/perl -w
#
# this is just a quick dumper of the file using Data::Dumper
#

use strict;
use MIME::Base64;
use JSON;
use Data::Dumper;
$Data::Dumper::Purity = 0;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Sortkeys = 1;

sub expand_nested {
        my ($in) = @_;

        die "expecting a hash" if ref($in) ne 'HASH';

        my %out = ();

        foreach my $k (sort keys %$in) {
                $out{$k} = decode_json( $in->{$k} );
        }

        return \%out;
}

sub dumpfile {
        my ($file) = @_;

        open(IN, $file) || die "$file: failed to open";
        my $txt = <IN>;
        close(IN);

        if (my $dec = decode_base64($txt)) {
                $txt = $dec;
        }

        my $j = decode_json($txt);

        my $e = expand_nested($j);

        print Dumper($e);
}

my $file;

die "$0 <progressionbackup>\n" if $#ARGV < 0;

foreach my $file (@ARGV) {

        dumpfile($file);
}
