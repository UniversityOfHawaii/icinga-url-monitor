#!/usr/bin/perl -w

use strict;
use warnings;

use URI;
use Test::Simple tests => 3;
use Test::Script::Run;

my $script = 'url_reachability_tester.pl';
my $appName = "some app";

my $invalidUrl = "non-url";
my $invalidResult = "UNKNOWN";
run_output_matches(
    $script,
    [
        "--timeout", 1,
        "--name", $appName,
        "--url", $invalidUrl
    ],
    [
        "$script $invalidResult - invalid URL \'$invalidUrl\'"
    ],
    undef,
    "invalid URL error"
);

my $timeoutURI = URI->new("http://web10.its.hawaii.edu:1234");
my $timeoutResult = "CRITICAL";
my $timeoutHost = $timeoutURI->host_port;
run_output_matches(
    $script,
    [
        "--timeout", 1,
        "--name", $appName,
        "--url", $timeoutURI
    ],
    [
        "$script $timeoutResult - error contacting \'$appName\' (\'$timeoutURI\'): 500 Can't connect to $timeoutHost (timeout)"
    ],
    undef,
    "unreachable host error"
);

my $okURI = URI->new("https://www.hawaii.edu/prof/");
my $okResult = "OK";
my $casURI = URI->new("https://authn.hawaii.edu/cas/login");
run_output_matches(
    $script,
    [
        "--timeout", 1,
        "--name", $appName,
        "--url", $okURI
    ],
    [
        "$script $okResult - contacted \'$appName\' (\'$okURI\' redirected to \'$casURI\')"
    ],
    undef,
    "success"
);
