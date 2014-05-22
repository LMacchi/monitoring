#!/usr/bin/perl
# This script retrieves data from tomcat garbage collector using SNMP
# It does not evaluate the result, just displays it
# You'll need snmp enabled in tomcat
# https://github.com/LMacchi

use warnings;
use strict;
use SNMP::Simple;
use Getopt::Long qw(:config no_ignore_case);

my ($host, $comm, $ver);
my $result = GetOptions(
"H|host=s"		=> \$host,
"C|community=s"         => \$comm,
"V|version=s"   	=> \$ver,
);

# Check if all the mandatory vars are provided
if ( (!defined($host)) || (!defined($comm)) || (!defined($ver)) ) {
	usage();
}

my $s = new SNMP::Session(
	DestHost => $host,
	Community => $comm,
	Version => $ver,
) or die "couldn't create session";

my $results = $s->gettable('JVM-MANAGEMENT-MIB::jvmMemGCTable');

my $index;
my $msg="OK - GC Threads - ";
my $perfdata;
foreach $index (keys %{$results}) {
        my $time=$results->{$index}->{'jvmMemGCTimeMs'};
        my $count=$results->{$index}->{'jvmMemGCCount'};
        $msg.="[Count: $count Time: $time Ms] ";
        $perfdata.="GCTime$index=$time;;;;; GCCount$index=$count;;;;; ";
}

print "$msg | $perfdata\n";
exit 0;

sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H hostname -V version -C community\n";
        print "\n";
	print "Get Tomcat Garbage Collector stats using SNMP. The results include perfdata for PNP4nagios.\n";
	print "This script does not evaluate results, the main objective is graphing.\n";
        exit 3;
}

