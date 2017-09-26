#!/usr/bin/perl -w
use strict;

use Data::Dumper;
use REST::Client;
use MIME::Base64;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON;


# do a post to weightxreps.net/save-{YYYY-MM-DD}
my $date = '2017-07-01';
my $host = "http://weightxreps.net";
my $path = "/save-$date";

my $client = REST::Client->new(host => $host);

print "URL: $host$path\n";

my $bw = 186.6;
my $log = 'testing';

my $user = 'bartman';
my $pass = '1qaz2wsxWxR';

#"bw" float. Bodyweight on that day...
#"log" BASE64 of the log's text. 
#"user" username
#"pass" MD5 of the password

my %data = (
        bw => $bw,
        log => encode_base64($log, ''),
        user => $user,
        pass => md5_base64($pass),
);
print "Data: " . Dumper(\%data) . "\n";

my $json = encode_json(\%data);
my $json = 'xxx';
#$json = '{"bw":"186","log":"dGVzdGluZw==","user":"bartman","pass":"198df139521b9e3d89b74fd85090b62a"}';
print "JSON: $json\n";
$client->POST( $path, $json );

my $c = $client->responseCode();
my $r = $client->responseContent();

print "Response: $c '$r'\n";
die if( $client->responseCode() >= 300 );

# RETURNS a JSON
# { ok:1, error:"text of the error if not ok..." }
$r = decode_json($r);
print "JSON: " . Dumper($r) . "\n";
