#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;

my @hosts;

my $red=95;
my $yellow=90;

my $redmail='ic-it@icontrol.com';
my $yellowmail='jmiller@icontrol.com';
my $mailFrom='tomcatmonitor@polaris.icontrol.com';


my $hostfile="/usr/local/sbin/hosts.run";


open ( HOSTS, "<${hostfile}" );

if ( fileno HOSTS )
{

	while ( <HOSTS> )
	{
		chomp $_;
		if ( $_ )
		{
			push ( @hosts, $_ );
		}
	}
}
else
{
	die "Unable to load hosts!\n";
}

sub sendmail 
{
	my $to = $_[0];
	my $from = $_[1];
	my $subject = $_[2];
	my $body  = $_[3];

	open ( MAIL , "| /usr/sbin/sendmail -t" ) or warn "Unable to sendmail!\n";

	if ( fileno MAIL )
	{
		print MAIL "TO: ${to}\n";
		print MAIL "FROM: ${from}\n";
		print MAIL "SUBJECT: ${subject}\n\n";

		print MAIL "${body}\n";
		close MAIL;
	}
}

	
foreach my $chost ( @hosts )
{
	if ( $chost eq "w1" || $chost eq "w2" || $chost eq "j2" || $chost eq "j3" || $chost eq "ns0" || $chost eq "ns1" || $chost eq "ns2" )
	{
		next;
	}

	my $FILE=`ssh ${chost} "file /data/ic/tomcat/conf/server.xml 2> /dev/null"`;

	if ( $FILE =~ m/ASCII text/i )
	{
		my $threaddump=`ssh -T ${chost} < /usr/local/sbin/getRemoteThreadDump 2> /dev/null`;
		
		if ( $threaddump )
		{
			my $temp = $threaddump;
			my $total;
			my $used;
			my $perc;
			my $name;
			my %data;

			my %redalarms;
			my %yellowalarms;

			my @lines = split ( "\n", $temp );

			foreach my $line ( @lines )
			{
				if ( $line =~ m/used (\d+)K/i)
				{
					$line =~ s/\[(.*)\)$//g;
					$line =~ s/^(\s+)//g;
					$line =~ s/(\s+)/ /g;

					if ( $line =~ m/^(.*) total (\d+)[K,k], used (\d+)[K,k]/ )
					{
						my $percentage = $3 / $2;
						$percentage = $percentage * 100;
						$name = $1;
						$total = $2;
						$used = $3;
						
						$perc = sprintf "%.2f", $percentage;

						$data{$name} = $perc;
						

						
					}
				}
			}
			foreach my $dd ( keys ( %data ) )
			{
				if ( $data{"$dd"} =~ /^((\d+)\.(\d+)|(\d+))$/ )
				{
					if ( $data{"$dd"} >= $yellow && $data{"$dd"} < $red )
					{
						$yellowalarms{$dd} = $data{$dd};
					}
					if ( $data{"$dd"} >= $red )
					{
						$redalarms{$dd} = $data{$dd};
					}
				}
			}
			my $mBody;

			if ( %redalarms )
			{
				$mBody .= "Red Alarms\n";
				$mBody .= "-" x 50 . "\n";
				foreach my $alarm ( keys ( %redalarms ) )
				{	
					$mBody .= $alarm . ": " . $redalarms{$alarm} . "%\n";
				}

				$mBody .= "\n\n";
			}
			
			if ( %yellowalarms )
			{
				$mBody .= "Yellow Alarms\n";	
				$mBody .= "-" x 50 . "\n";
				foreach my $alarm ( keys ( %yellowalarms ) )
				{
					$mBody .= $alarm . ": " . $yellowalarms{$alarm} . "%\n";
				}

				$mBody .= "\n\n";
			}

		
			my $mTo;
			my $mFrom;
			my $mailSubject;

			if ( %redalarms || %yellowalarms )
			{
				if ( %redalarms )
				{
					$mTo = $yellowmail . ',' . $redmail;
					$mFrom = $mailFrom;
					$mailSubject = "Tomcat Heap Usage Alert on ${chost}";

				}
				elsif ( %yellowalarms )
				{
					$mTo = $yellowmail;
					$mFrom = $mailFrom;
					$mailSubject = "Tomcat Heap Usage Alert on ${chost}";
				}

				if ( $mBody )
				{
					sendmail ( $mTo, $mFrom, $mailSubject, $mBody );
				}
			}
					
		}
	}
}
	


