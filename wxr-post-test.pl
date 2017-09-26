#!/usr/bin/perl -w
use strict;

use DateTime;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common;
use MIME::Base64;
use Digest::MD5 qw(md5_hex);
use JSON;

my $date = DateTime->now->ymd;  # today in 'YYYY-MM-DD' format
my $bw = 190;
my $log = '
testing submission script

#squat
315 x 5 x 5
#deadlift
315 x 5
#bench-press
225 x 5
#pullup
BW x 10 x 2
#tricep-dips
BW+45 x 10 x 2

';

# do a post to weightxreps.net/save-{YYYY-MM-DD}
my $host = "http://weightxreps.net";
my $path = "save-$date";
my $url = "$host/$path";

print "URL: $url\n";

my $secrets = ".wxrsecrets";
open(SEC, "<", $secrets) || die "create a file named $secrets and put your username and password in it, one per line\n";
my $user = <SEC>; chomp $user;
my $pass = <SEC>; chomp $pass;
close SEC;

print "user $user\n";

my $ua = LWP::UserAgent->new;
my $h = HTTP::Headers->new(
        'X-Requested-With' => 'XMLHttpRequest',
);
$ua->default_headers($h);
my %data = (
        bw => $bw,                         #"bw"   float. Bodyweight on that day...
        log => encode_base64($log, ''),    #"log"  BASE64 of the log's text. 
        user => $user,                     #"user" username
        pass => md5_hex($pass),            #"pass" MD5 of the password
);

my $r = $ua->request(POST "$url", \%data);

print "Status  " . $r->status_line     . "\n";
print "Content " . $r->content         . "\n";
print "Success " . $r->is_success      . "\n";
