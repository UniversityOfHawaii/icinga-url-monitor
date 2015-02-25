#!/usr/bin/perl -w
######################################################################
## Filename:      prtl.pl
## Version:       $Id$
## Description:   time a login to the portal, reporting any errors
## Author:        joseph dane <jdane@hawaii.edu>
## Created at:    Thu Nov  4 13:30:17 2004
## Modified at:   Mon Nov 22 15:46:54 2004
## Modified by:   joseph dane <jdane@hawaii.edu>
## Messed up by:  ward takamiya <ward@hawaii.edu>
##                1/11/2011 added feature to try to click through to banner
######################################################################

use LWP::UserAgent;
use FileHandle;
use strict;

my $log = new FileHandle;

$log->open('/dev/null', ">");
#$log->fdopen(fileno(STDERR), ">");

#my $portal_login = 'https://myuhportal.hawaii.edu/cp/home/login';
my $host = $ARGV[0] or die "No host specified.";
my $warning = $ARGV[1] or die "No warning timeout specified.";
my $critical = $ARGV[2] or die "No critical timeout specific.";
my $portal_login = "https://$host/cp/home/login";

# this URL should be blocked by the firewall.  meaning it can be useful
# for testing timeouts.
#my $portal_login = 'http://web10.its.hawaii.edu:1234';

# number of seconds to pause before submitting requests.  should be
# zero unless we're debugging
my $pause = 0;
my $state = 0;
# add any additional headers we want to send here
my %headers = (
    Accept => '*/*',
);

# the portal reads UserAgent and won't work at all if we use
# the default LWP agent string.  Safari seems to work, so ...
my $agent_id =  'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/125.5 (KHTML, like Geck
o) Safari/125.9';

my $ua =
    LWP::UserAgent->new(requests_redirectable => [],
                        cookie_jar => {},
                        timeout => 60,
                        agent => $agent_id);

my $start_time = time;

my $url = $portal_login;
printf $log "logging in to %s\n", $url;
my $res = $ua->post($url,
                    { user => 'xxxxxxxxxx', pass => 'xxxxxxxxxx' , uuid => '0xACA021'},
                    %headers);
check_response('initial login', $res);

 my $counter = 1;

while (1) {
    my $redirect_target = undef;
    my $body = $res->as_string;
#    my $counter = 1;

    # the portal sends several redirect before we finally land on the
    # "home" page.  the redirects happen in three different ways
    # 1. a "normal" redirecting, using a 300 level HTTP status code and
#    a Location header
# 2. javascript setting document.location
# 3. javascript setting window.top.location
#
# Why do they do it in three different ways?  Beats me.

    # sanity check, to prevent infinite loops
    if ($counter > 20) {
        fail('redirects', 'detected possible infinite loop');
        last;
    }

    if ($res->is_redirect) {
        $redirect_target = $res->header("Location");
    }
    elsif ($body =~ /document\.location=[^"]*"([^"]+)"/s or
             ($body =~ /window\.top\.location=[^"]*"([^"]+)"/s)) {
#        $redirect_target = $1;
# added below 9/9/10 w.t.
  if ($1 =~ /^http/) {
    #print "absolute URL with http so leave alone\n";
    $redirect_target = $1;
  }
  else {
    #print "relative URL. fixing...";
    my $temp = $1;
    $temp =~ s/^\///; #remove double slashes
    $redirect_target= "http://$host/$temp";
  }
# added above 9/9/10 w.t.
#

    } #elsif

    if ($redirect_target) {
        printf $log "redirect to %s\n", $redirect_target;
        $res = $ua->get($redirect_target);
        check_response($redirect_target, $res);
        $counter++;
    }
    else {

        # now we should be on the portal home page.  we'll look
        # for something in the body so we're sure we've got a correct
        # page, and not some sort of error message.  how about the
        # "Add/Drop Courses" link?
        $body = $res->as_string;
        # if No Add/Drop link on the portal, then show as down
        $body =~ /Add\/Drop/s
            or fail('portal home page', 'failed to find the "Add/Drop" link');

### added 1/11/11 w.t. below ###
#if Add/Drop is there, try to reach main menu?

         my $nextclicklink = "https://myuh.hawaii.edu/cp/ip/login?sys=sctssb&url=https://www.sis.haw
aii.edu/uhdad/twbkwbis.P_GenMenu?name=bmenu.P_MainMnu&msg=WELCOME";
#         my $nextclicklink = "https://myuh.hawaii.edu/cp/ip/login?sys=sctssb&url=https://lum90.its.
hawaii.edu/uhdad/twbkwbis.P_GenMenu?name=bmenu.P_MainMnu&msg=WELCOME";

         # i think this should get to banner via the portal, so should be suitable

         $res = $ua->get($nextclicklink);

         $counter = 1;
         while (1) {
           if ($counter > 20) {
              fail('redirects', 'detected possible infinite loop');
              last;
           }

           check_response($nextclicklink, $res);

           if ($res->is_redirect) {
              $redirect_target = $res->header("Location");
              $res = $ua->get($redirect_target);
              printf $log "redirect to %s\n", $redirect_target;
              $counter++;
           }
           else { last; }
         }

#we should now be at final banner page--the main menu:

        $body = $res->as_string;
        #$body = "blah Error: Academic Services Unavailable yeah right <H2>Main Menu";
        #print "2.body=$body\n";

        if ($body =~ /Error: Academic Services Unavailable/) {
            warning('banner home page', 'Academic Services Not Ready');
        }


        if ($body !~ /<H2>Main Menu/i) {
            fail('banner main menu', 'failed to find Academic Services main menu');
        }

        else {
           printf $log "found \"<H2>Main Menu\" on %s\nDone.\n", $redirect_target;
        }

### added 1/11/11 w.t. above ###

        ok(time - $start_time);
        last;

    } #else
    sleep $pause;;

} #while
# END of program flow.

sub check_response {
    my ($location, $res) = @_;
    if (not defined $res) {
        fail($location, "undefined response");
    }
    if ($res->is_success or $res->is_redirect) {
        return 1;
    }
    my $status = $res->status_line;
    if ($status =~ /connect: timeout/) {
        fail($location, "connection attempt timed out");
    }
    fail($location, $res->status_line);
}

sub fail {
    my ($location, $msg) = @_;
#    mrtg_out(1000);
        $state = "2";
    print "CRITICAL - $msg\n";
#    die sprintf "%s: %s\n", $location, $msg;
    exit($state);
}

sub warning {
    my ($location, $msg) = @_;
#    mrtg_out(1000);
        $state = "2";
    print "WARNING - $msg\n";
#    die sprintf "%s: %s\n", $location, $msg;
    exit($state);
}


sub ok {
    my $elapsed = shift;
    if ($elapsed <= $warning) {
       printf "OK - %d seconds\n", $elapsed;
        $state = "0";
        exit($state);
    }
    elsif (($elapsed > $warning) && ($elapsed <= $critical)) {
        $state = "1";
       printf "WARNING: %d seconds\n", $elapsed;
        exit($state);
    }
    else {
        $state = "2";
       printf "CRITICAL - Plugin Timed Out or Too Delayed %d seconds \n", $elapsed;
        exit($state);
    }
#    mrtg_out($elapsed);
}

sub mrtg_out {
    my $elapsed = shift;
    printf "%d\n", $elapsed;
    print "0\n";
    print "NA\n";
    print "portal login time\n";
}
#
