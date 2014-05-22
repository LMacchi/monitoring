#!/usr/bin/perl
# Get apache stats using server-status page
# mod_status needs to be enabled in httpd
# and the acl needs to allow the nagios box to access it
# https://github.com/LMacchi

use strict;
use Getopt::Long;

my $debug = 0;

my $host;
my $output;
my %outputs = ("cpu" => 1, "requests" => 1, "servers" => 1, "all" => 1);

GetOptions ( 	"H|host=s" => \$host,
		"O|output=s" => \$output,
           );

if (!defined($host)) {
	usage();
}

if ($outputs{lc($output)} != "1") {
	usage();
}

my $cpuload;
my $reqpersec;
my $busy;
my $idle;

my @data = `/usr/bin/curl "http://$host/server-status?auto" 2>&1`;

if ($? eq 0) {
	foreach my $data (@data) {
		if ($data =~ m/CPULoad: (.*)/) {
			$cpuload = $1;
			print "CPU Load: $cpuload\n" if $debug;
		} elsif ($data =~ m/ReqPerSec: (.*)/) {
         		$reqpersec = $1;
         		print "ReqPerSec: $reqpersec\n" if $debug;
	      	} elsif ($data =~ m/BusyWorkers: (.*)/) {
                       	$busy = $1;
			print "BusyWorkers: $busy\n" if $debug;
	        } elsif ($data =~ m/IdleWorkers: (.*)/) {
                	$idle = $1;
			print "IdleWorkers: $idle\n" if $debug;
		}
	}
}

if (lc($output) eq "cpu") {
	print "OK - Apache is running | cpuload=$cpuload;;;;\n";
} elsif (lc($output) eq "servers") {
	print "OK - Apache is running | busyservers=$busy;;;;; idleservers=$idle;;;;\n";
} elsif (lc($output) eq "requests") {
	print "OK - Apache is running | requests=$reqpersec;;;;;\n";
} elsif (lc($output) eq "all") {
	print "OK - Apache is running | cpuload=$cpuload;;;; requests=$reqpersec;;;;; busyservers=$busy;;;;; idleservers=$idle;;;;\n";
}

exit 0;

sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H, --host hostname -O, --output cpu|servers|requests|all\n";
        print "\n";
	print "Allowed output: cpu, servers, requests or all\n";
        print "Get Apache stats using Server-Status. The results include perfdata for PNP4nagios.\n";
        print "This script does not evaluate results, the main objective is graphing.\n";
        exit 3;
}
