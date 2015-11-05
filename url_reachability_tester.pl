#!/usr/bin/perl -w
######################################################################
## Filename:      reverse_proxy_tester.pl
## Version:       $Id$
## Description:   
## Author:        wes price <wprice@hawaii.edu>
## Created at:    Thu Feb  19 15:30 2015
######################################################################
use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

use Data::Validate::URI qw(is_web_uri);
use File::Basename;
use LWP::UserAgent;
use Monitoring::Plugin;
use URI::Encode qw(uri_decode);


my $DEFAULT_TIMEOUT = 15;
my $VERSION = '1.0';

# get the base name of this script for use in the examples
my $PROGNAME = basename($0);


# instantiate Monitoring::Plugin
my $p = Monitoring::Plugin->new(
    usage => "Usage: %s -n <name> -u <url> [-t <timeout>] [-v]",
    version => $VERSION,
    shortname => $PROGNAME,
    license =>
"This icinga plugin was developed for monitoring the availability of web
applications developed by UH Manoa ITS, and may be freely used,
redistributed, and/or modified."
);


# define and document valid command line options
# (usage, help, version, timeout and verbose are defined by default)

$p->add_arg(
    spec => 'url|u=s',
    help =>
qq{-u, --url=STRING
   The url being tested},
   required => 1
);

$p->add_arg(
    spec => 'name|n=s',
    help =>
qq{-n, --name=STRING
   The name of the application being tested},
   required => 1
);

# parse arguments and process standard ones
$p->getopts;

# sanity-check input parameters
my $timeout = $p->opts->timeout;
if (defined $timeout) {
    if ($timeout < 0) {
        $p->plugin_die( "timeout must be >= 0" );
    }
    else {
        print "set timeout to $timeout\n" if $p->opts->verbose;
    }
} else {
    $timeout = $DEFAULT_TIMEOUT;
    print "using default timeout of $timeout\n" if $p->opts->verbose;
}

my $name = $p->opts->name;
my $url = $p->opts->url;
if (defined(is_web_uri( $url ))) {
    print "validated URL \'$url\'\n" if $p->opts->verbose;
}
else {
    $p->plugin_die( "invalid URL \'$url\'" );
}


# perform the actual reachability test
my $ua = LWP::UserAgent->new;
$ua->agent("$PROGNAME/$VERSION");
$ua->timeout($timeout);

my $req = HTTP::Request->new(GET => $url);
print "sending request to $name ($url)\n" if ($p->opts->verbose > 1);
my $res = $ua->request($req);
print "received response from $name ($url)\n" if ($p->opts->verbose > 1);

print Dumper($res) if ($p->opts->verbose > 2);

my ($resultCode, $message);

my $urlList = "'$url'";
if ($res->redirects) {
    my $lastRedirect = ($res->redirects)[0];
    my $lastLocation = uri_decode($lastRedirect->header('location'));
    $lastLocation =~ s/\?.*$//;
    $urlList .= " redirected to '$lastLocation'";
}

if ($res->is_success) {
    $resultCode = 0;
    $message = "contacted \'$name\' ($urlList)";
}
else {
    if ($res->redirects) {
        # initial contact resulted in at least one redirect,
        # so the actual server-of-interest is alive
        $resultCode = 1;
    }
    else {
        # no successful redirects before failure
        $resultCode = 2;
    }
    $message = "error contacting \'$name\' ($urlList): " . $res->status_line;
}


# result codes:
# 0 == OK
# 1 == warning
# 2 == critical
$p->plugin_exit(
    return_code => $resultCode,
    message => $message
);

__END__

=head1 url_reachability_tester

url_reachability_tester -- verifies that the given website URL can be reached 

=head1 SYNOPSIS

Usage: url_reachability_tester -n <name> -u <url> [-t <timeout>] [-v]

=head1 DESCRIPTION

Icinga-compatible plugin script which Uses LWP::UserAgent to connect to the
given URL, returning OK status if the connection attempt succeeds (with an
HTTP result code of 200), WARNING status if at least one redirect succeeds
but the final one failed, or CRITICAL status for any other result (timeout,
invalid URL, or last HTTP status code != 200)

The following command-line parameters are supported:

=over 4

=item  -?, --usage
Print usage information

=item -h, --help
Print detailed help screen

=item -V, --version
Print version information

=item -n, --name=STRING (required)
Specify the name of the application being tested

=item -u, --url=STRING (required)
Specify the url being tested

=item -t, --timeout=INTEGER
Seconds before plugin times out (default: 15)

=item -v, --verbose
Print debugging-related details during execution (can repeat up to 3 times
to increase verbosity)

=back

=head1 AUTHOR

Developed and maintained by Wes Price (wprice@hawaii.edu), UH ITS/MIS

=cut
