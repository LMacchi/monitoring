#!/usr/bin/perl
# A simple script to retrieve squid http stats using snmp
# You need to enable snmp in your squid conf
# The main purpose is to graph the stats, so the results are not parsed
# https://github.com/LMacchi

use strict;
use SNMP::Simple;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);
use Cache::Memcached;

#$SNMP::debugging=2;

my $code = 0;
my $retries = 2;
my $timeout = 10000000;
my $verbose = 0;
my %values = ("HTTPReqs" => 0, "HTTPHits" => 0, "HTTPErrs" => 0);
my %oids = ("HTTPReqs" => ".1.3.6.1.4.1.3495.1.3.2.1.1.0", "HTTPHits" => ".1.3.6.1.4.1.3495.1.3.2.1.2.0", "HTTPErrs" => ".1.3.6.1.4.1.3495.1.3.2.1.3.0");
my ($host, $comm, $ver, $help);
my $options = GetOptions(
	"H|host=s"		=> \$host,
	"C|community=s"         => \$comm,
	"V|version=s"   	=> \$ver,
	'h|help' 		=> \$help,
	'v|verbose+'		=> \$verbose,

);

if ($help) {	
	usage();
}

# Check if all the mandatory vars are provided
if ( (!defined($host)) || (!defined($comm)) || (!defined($ver)) ) {
	usage();
}

$ENV{'MIBS'} = "ALL";

my $s = new SNMP::Session (
	DestHost => $host,
	Community => $comm,
	Version => $ver,
	Retries => $retries,
	Timeout => $timeout,
) or die "couldn't create session";

foreach my $key ( sort keys %oids) {
	my $oid = $oids{$key};
	my $value = $s->get($oid); 
	check_result($value, $s->{ErrorStr});
	debug ($value, $oid);
	$values{$key} = $value;
}

my $msg = "OK - ";
my $perf = " | ";
foreach my $key ( sort keys %values) {
	if (defined($values{$key})) {
		$msg .= $key . " = " . $values{$key} . " ";
		$perf .= $key . "=" . $values{$key} . ";;;;; ";
	} else {
		print "Error - Try again\n";
		exit 2;
	}
}

print $msg . $perf . "\n";
exit 0;
	
# Subroutines

sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H hostname -V version -C community\n";
        print "\n";
	print "\tGet squid http stats using SNMP. The results include perfdata for PNP4nagios.\n";
	print "\tUse -v to show debug info.\n";
        exit 3;
}

sub debug {
        my ($var, $desc) = @_;
	if ($verbose > 0) {
		print "DEBUG: | $desc = $var |\n";
	}
}

sub check_result {
        my ($result, $error) = @_;
        if ($error) {
                print "SNMP Session error: $error.\n";
                exit 2;
        }
        if (!defined($result)) {
                print "OID could not be retrieved\n";
                exit 2;
        }
        if ($result =~ /NOSUCH/) {
                print "Check your OID, Error: $result.\n";
                exit 2;
        }
}
