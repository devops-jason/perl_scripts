#!/usr/bin/perl -w

# 
# dataFilter.pl 12/8/2008 - David DeVault
#
# pad date timestamp to STDIN
#
########################################################

use POSIX qw(strftime);

#2008 Dec 04 Thu 16:01:52 PST -
my $tstamp;

while (<STDIN>) {

		$tstamp = strftime "%Y %b %d %a %H:%M:%S %Z", localtime;
		chomp $_;
		print "${tstamp} - $_\n"

} # end while
