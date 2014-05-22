#!/usr/bin/perl
# I use memcache for most of my snmp checks, so it only makes sense to monitor it is working right
# The aim of this script is to generate graphs, not to alert in case of issues
# so the results are not parsed.

use strict;
use lib '/root/Cache-Memcached-1.30/lib';
use Cache::Memcached;
use Getopt::Long qw(:config no_ignore_case);

# Var declaration
my @data_total = ( "bytes_written", "bytes_read", "curr_items", "bytes", "get_hits", "get_misses", "cmd_set", "cmd_get");
my @data_misc = ( "limit_maxbytes", "curr_connections");
my $message = "OK - Retrieving Memcache Stats | ";
my $index;
my $verbose = 0;
my $host;
my $help;

my $options = GetOptions(
        "H|host=s"              => \$host,
        'h|help'                => \$help,
        'v|verbose+'            => \$verbose,

);

if ($help) {
        usage();
}

if (!defined($host)) {
	usage();
}

# New memcache session
my $memd;
$memd = new Cache::Memcached {
	'servers' => [ "$host:11211" ],
	'debug' => 0,
	'compress_threshold' => 10_000,
} or die "could not create session";

# Retrieve stats
my $stats = $memd->stats();

if (!defined($stats->{'total'})) {
        print "Critical - Stats could not be retrieved [Does your server run memcache?]\n";
        exit 2;
}


# Select the stats we will use from section "total"
foreach $index (@data_total) {
	my $val .= $stats->{"total"}->{$index};
	debug ($val, $index);
	$message .= "$index=$val ";
}

# Select the stats we will use from section "misc"
foreach $index (@data_misc) {
        my $val .= $stats->{"hosts"}->{"$host:11211"}->{"misc"}->{$index};
        debug ($val, $index);
        $message .= "$index=$val ";
}

# Return a message with all the retrieved variables
print "$message\n";
exit 0;

sub usage {
        my $program = $0;
        print "Usage\n";
        print "\t$0 -H hostname\n";
        print "\n";
        print "\tScript to retrieve memcache status";
        print "\tUse -v to show debug info.\n";
        exit 3;
}

sub debug {
        my ($var, $desc) = @_;
        if ($verbose > 0) {
                print "DEBUG: | $desc = $var |\n";
        }

}    
