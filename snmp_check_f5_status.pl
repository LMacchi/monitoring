#!/usr/bin/perl
# This script monitors F5 status changes from Active to Stand-By and the other way around.
# It stores previous status on memcache, allowing to alert only after 3 polling cycles,
# instead of alerting at first try. Bye bye false alerts! Well, most of them anyway.
# Allow 3 polling cycles for the script to have enough data.
# You'll have to extend a little bit to add snmp v3 variables.

use strict;
use Cache::Memcached;
use SNMP;
use Getopt::Long qw(:config no_ignore_case);

my @status = ("STAND-BY", "UNUSED", "UNUSED", "ACTIVE");
my $verbose = 1;
my $host;

# Let's define the memcache settings
my $memd = new Cache::Memcached {
        'servers' => [ "127.0.0.1:11211" ],
        'debug' => 0,
        'compress_threshold' => 10_000
};

my $retries = 5;
my $verbose = 0;
my ($host, $comm, $ver, $oid, $help);
my $options = GetOptions(
        "H|host=s"              => \$host,
        "C|community=s"         => \$comm,
        "V|version=s"           => \$ver,
        'h|help'                => \$help,
        'v|verbose+'            => \$verbose,

);

$oid = "F5-BIGIP-SYSTEM-MIB::sysAttrFailoverUnitMask.0";

if ($help) {
        usage();
}

# Check if all the mandatory vars are provided
if ( (!defined($host)) || (!defined($comm)) || (!defined($ver)) || (!defined($oid)) ) {
        usage();
}

# SNMP does not work well with oids in string notation, so let's convert it to numeric
my $oid_num = SNMP::translateObj($oid);
debug ($oid_num, "oid");

$ENV{'MIBS'} = "ALL";

my $s = new SNMP::Session (
        DestHost => $host,
        Community => $comm,
        Version => $ver,
        Retries => $retries,
) or die "couldn't create session";

# Let's get the current status
my $curr = $s->get("$oid_num");
debug ($curr, "Result");

# Each status var holds a previous status. 3 is the previous, 2 the one before that, etc.
my $status1 = $memd->get("$host:status_mask1");
debug ($status1, "Status 1");
my $status2 = $memd->get("$host:status_mask2");
debug ($status2, "Status 2");
my $status3 = $memd->get("$host:status_mask3");
debug ($status3, "Status 3");

if (!defined($status1)) {
	if (!defined($status2)) {
		if ( !defined($status3)) { # Assign current to status3
			$memd->set("$host:status_mask3",$curr);
			print "Not enough data, please run 3 more times\n";
			exit 3;
		}
		debug ($status3, "Status3 exists");
		$memd->set("$host:status_mask2",$status3);
		$memd->replace("$host:status_mask3",$curr);
		print "Not enough data, please run 2 more times\n";
		exit 3;
	}
	debug($status2, "status2 exists");
	$memd->set("$host:status_mask1",$status2);
	$memd->replace("$host:status_mask2",$status3);
	$memd->replace("$host:status_mask3",$curr);
	print "Not enough data, please run again\n";
	exit 3;
}
	
# We have enough data, let's continue
	
# We're going to use the oldest to compare. Save it.
my $oldest = $status1;

# Now let's switch all the values, drop status1, change status2 to 1, status3 to 2 and current to status3
my $status1 = $memd->replace("$host:status_mask1",$status2);
my $status2 = $memd->replace("$host:status_mask2",$status3);
my $status3 = $memd->replace("$host:status_mask3",$curr);

# Now let's return a result
if ($curr == $oldest) {
	print "OK - STATUS UNCHANGED: $status[$curr]\n";
	exit 0;
} else {
	print "CRITICAL - STATUS CHANGE: from $status[$oldest] to $status[$curr]\n";
	exit 2;
}
	
sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H hostname -V version -C community\n";
        print "\n";
	print "\tScript to detect F5 status changes.\n";
        print "\tCAUTION: Use only OIDs in string notation, otherwise the script will fail.\n";
        print "\tUse -v to show debug info.\n";
        exit 3;
}

sub debug {
        my ($var, $desc) = @_;
        if ($verbose > 0) {
                print "DEBUG: | $desc = $var |\n";
        }

}	
