#!/usr/bin/perl
# This script allows you to retrieve information about Tomcat Mempools.
# You need to have snmp enabled in your tomcat configuration and
# the java mib (JVM-MANAGEMENT-MIB) in your mib directory.
# https://github.com/LMacchi

use warnings;
use strict;
use SNMP::Simple;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

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

my $results = $s->gettable('JVM-MANAGEMENT-MIB::jvmMemPoolTable');

#print Dumper($results);
my $index;
my $msg="OK - Graphing Memory Pools";
my $perfdata;
foreach $index (keys %{$results}) {
        my $name=$results->{$index}->{'jvmMemPoolName'};
        my $used=$results->{$index}->{'jvmMemPoolUsed'};
	my $max=$results->{$index}->{'jvmMemPoolMaxSize'};
	$name =~ s/ //g;
        $perfdata.=$name."=".$used."B;;;;$max ";
}

print "$msg | $perfdata\n";
exit 0;

sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H hostname -V version -C community\n";
        print "\n";
	print "Get Tomcat Memory Pool stats using SNMP. The results include perfdata for PNP4nagios.\n";
	print "This script does not evaluate results, the main objective is graphing.\n";
        exit 3;
}

