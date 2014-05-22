#!/usr/bin/perl
# This is a skeleton check, nothing fancy, just retrieves an snmp
# variable and evaluates based on provided thresholds.
# https://github.com/LMacchi

use strict;
use SNMP::Simple;
use Getopt::Long qw(:config no_ignore_case);

#$SNMP::debugging=2;

my $code = 0;
my @exits = ("OK", "WARNING", "CRITICAL", "UNKNOWN");
my ($host, $comm, $ver, $oid, $unit, $warn, $crit);
my $result = GetOptions(
"H|host=s"		=> \$host,
"C|community=s"         => \$comm,
"V|version=s"   	=> \$ver,
"o|oid=s"		=> \$oid,
"u|unit=s"		=> \$unit,
"w|warning=s"		=> \$warn,
"c|critical=s"		=> \$crit,
);

# Check if all the mandatory vars are provided
if ( (!defined($host)) || (!defined($comm)) || (!defined($ver)) || (!defined($oid)) || (!defined($unit)) ) {
	usage();
}

if ( (defined($warn)) && (!defined($crit)) || (defined($crit)) && (!defined($warn)) ) { 
	print "Define warning AND critical.\n";
	exit 3;
}

my $s = new SNMP::Session (
	DestHost => $host,
	Community => $comm,
	Version => $ver,
) or die "couldn't create session";

# Translate the oid to numeric form, for the sake of picky F5s
my $oid_num = SNMP::translateObj($oid);

my $var = $s->get("$oid_num");
	
if (!defined($var)) {
	print "OID could not be retrieved\n";
	exit 2;
}

if ($var =~ /NOSUCH/) {
	print "Check your OID and try again. ERROR $var\n";
	exit 2;
}

if ((defined($warn)) && (defined($crit))) {
	$code = evaluate($var, $warn, $crit);
} 

print "$exits[$code]: $var $unit | $unit=$var;;;;\n";
exit $code;

sub evaluate {
	my ($var, $warn, $crit) = @_;
	if ($warn < $crit) {
		if ($var < $warn) {
			$code = 0;
		} else {
			if (($var >= $warn) && ($var < $crit)) {
				$code = 1;
			} else {
				$code = 2;
			}
		} 
	} else { # crit < warn
		if ($var > $warn) {
			$code = 0;
		} else {
			if (($var <= $warn) && ($var > $crit)) {
				$code = 1;
			} else {
				$code = 2;
			}
		}
	}
	return $code;
}

sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H hostname -V version -C community -o OID -u unit [-w warning -c critical]\n";
        print "\n";
	print "Get stats using SNMP. The results include perfdata for PNP4nagios.\n";
        exit 3;
}
