#!/usr/bin/perl -w
######################################################################
## Filename:      reverse_proxy_tester.pl
## Version:       $Id$
## Description:   
## Author:        wes price <wprice@hawaii.edu>
## Created at:    Thu Feb  19 15:30 2015
######################################################################

##############################################################################
# prologue
use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Indent = 2;
$Data::Dumper::Sortkeys = 1;

use Data::Validate::URI qw(is_web_uri);
use File::Basename;
use LWP::UserAgent;
use Monitoring::Plugin;

my $DEFAULT_TIMEOUT = 60;
my $VERSION = '1.0';

# get the base name of this script for use in the examples
my $PROGNAME = basename($0);

##############################################################################
# define and get the command line options.
#   see the command line option guidelines at
#   https://www.monitoring-plugins.org/doc/guidelines.html#PLUGOPTIONS


# Instantiate Monitoring::Plugin object (the 'usage' parameter is mandatory)
my $p = Monitoring::Plugin->new(
    usage => "Usage: %s [ -v|--verbose ]  [-t <timeout>] -u <url> | --url <url> [-u <url> | --url <url> ...]",
    version => $VERSION,
    shortname => $PROGNAME
);


# Define and document the valid command line options
# usage, help, version, timeout and verbose are defined by default.

$p->add_arg(
    spec => 'url|u=s',
    help =>
qq{-u, --url=STRING
   Specify the full url being tested},
   required => 1
);

# Parse arguments and process standard ones (e.g. usage, help, version)
$p->getopts;


#
# sanity-check input parameters
my $url = $p->opts->url;
if (defined(is_web_uri( $url ))) {
    print " validated URL $url\n " if $p->opts->verbose;
}
else {
    $p->plugin_die( " invalid URL \'$url\'" );
}


my $timeout = $p->opts->timeout;
if (defined $timeout) {
    if ($timeout < 0) {
        $p->plugin_die( " timeout must be >= 0" );
    }
    else {
        print " set timeout to $timeout\n " if $p->opts->verbose;
    }
} else {
    $timeout = $DEFAULT_TIMEOUT;
    print " using default timeout of $timeout\n " if $p->opts->verbose;
}

##############################################################################
# verify reachability of the given url

my $ua = LWP::UserAgent->new;
$ua->agent("$PROGNAME/$VERSION ");
$ua->timeout($timeout);

my $req = HTTP::Request->new(GET => $url);
my $res = $ua->request($req);

# UNF: add a timeout, probably need to re-add the timeout param to the script



if (1 == 0) {
    print Dumper($res);
}

my ($resultCode, $message);

if ($res->is_success) {
    $resultCode = 0;
    $message = "contacted URL \'$url\'";
}
else {
    $resultCode = 2;
    $message = $res->status_line;
}


# result codes:
# 0 == OK
# 1 == warning
# 2 == critical
$p->plugin_exit(
    return_code => $resultCode,
    message => " $message"
);
