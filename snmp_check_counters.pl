#!/usr/bin/perl
# Script that stores previous results in memcache.
# the script will handle counters or integers
# It is specially useful for F5 stats, since they're all counters
# It is also the starting point for HA checks, since the active to
# passive change lasts only one cycle. You can compare previous
# results and alert on a change in the pattern
# LMacchi - 2013

use strict;
use SNMP::Simple;
use Getopt::Long qw(:config no_ignore_case);
use Cache::Memcached;

#$SNMP::debugging=2;

my $code = 0;
my $retries = 2;
my $timeout = 10000000;
my $verbose = 0;
my @exits = ("OK", "WARNING", "CRITICAL", "UNKNOWN");
my ($host, $comm, $ver, $oid, $unit, $warn, $crit, $help, $clear);
my $options = GetOptions(
	"H|host=s"		=> \$host,
	"C|community=s"         => \$comm,
	"V|version=s"   	=> \$ver,
	"o|oid=s"		=> \$oid,
	"n|name=s"		=> \$unit,
	"w|warning=s"		=> \$warn,
	"c|critical=s"		=> \$crit,
	'h|help' 		=> \$help,
	'v|verbose+'		=> \$verbose,
	'clear'			=> \$clear,

);

if ($help) {	
	usage();
}

# Check if all the mandatory vars are provided
if ( (!defined($host)) || (!defined($comm)) || (!defined($ver)) || (!defined($oid)) || (!defined($unit)) ) {
	usage();
}

if ( (defined($warn)) && (!defined($crit)) || (defined($crit)) && (!defined($warn)) ) { 
	print "Define warning AND critical.\n";
	exit 3;
}

# SNMP does not work well with oids in string notation, so let's convert it to numeric
my $oid_num = SNMP::translateObj($oid);
debug ($oid_num, "oid");

# Let's define the memcache settings
my $memd = new Cache::Memcached {
        'servers' => [ "127.0.0.1:11211" ],
        'debug' => 0,
        'compress_threshold' => 10_000
};

$memd->set_servers($memd->{'servers'});
$memd->set_compress_threshold(10_000);
$memd->enable_compress(0);

if (defined($clear)) {
        if ($memd->delete($oid_num)) {
                print "Cleared counter cache entry for [OID $oid_num].\n";
                exit 0;
        } else {
                print "Error clearing counter cache entry for [OID $oid_num].\n";
                exit 2;
        }
}

# Now for the SNMP part
$ENV{'MIBS'} = "ALL";

my $s = new SNMP::Session (
	DestHost => $host,
	Community => $comm,
	Version => $ver,
	Retries => $retries,
	Timeout => $timeout,
) or die "couldn't create session";

my $result = $s->get("$oid_num");
debug ($result, "Result");
	
if (!defined($result)) {
	print "OID could not be retrieved\n";
	exit 2;
}

if ($result =~ /NOSUCH/) {
	print "Check your OID, Error: $result.\n";
	exit 2;
}

my $type = &SNMP::getType($oid);
debug ($type, "OID type");

if ($type =~ /COUNTER/) {
        my $val = $memd->get("$host:$oid_num");
	debug($val, "Memcache value");
        if ($val) {
                $memd->replace("$host:$oid_num",$result);
                if ($result < $val) {
                        $result = 0xFFFFFFFFFFFFFFFF - $result + $val;
                } else {
                        $result = $result - $val;
                }
        } else {
                $memd->set("$host:$oid_num",$result);
		$result = 0;
	}
}

if ((defined($warn)) && (defined($crit))) {
	$code = evaluate($result, $warn, $crit);
} 

print "$exits[$code]: $unit = $result | $unit=$result;;;;\n";
exit $code;

# Subroutines
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
        print "\t$0 -H hostname -V version -C community -o OID -n VarName [-w warning -c critical]\n";
        print "\n";
	print "\tGet stats using SNMP. The results include perfdata for PNP4nagios.\n";
	print "\tCAUTION: Use only OIDs in string notation, otherwise the script will fail.\n";
	print "\tUse -v to show debug info.\n";
	print "\tUse -clear to clear a memcache entry.\n";
        exit 3;
}

sub debug {
        my ($var, $desc) = @_;
	if ($verbose > 0) {
		print "DEBUG: | $desc = $var |\n";
	}
}
