#!/usr/bin/perl

use warnings "all";

#use Net::SSH::Expect;
use File::Path;
use Net::SCP::Expect;

$configFile="/usr/local/sbin/ssg-config.list";

#.list File Format
##########################################
# hostname|username|password
##########################################


$dumpLoc="/data/network_configs/ssg/";

if (! -e $configFile)
{
        print "Error missing configuration file: $configFile \n";
        exit(0);
}

if (! -d $dumpLoc )
{
        mkpath("$dumpLoc") || die("Could not create directory");
}

#Open config file a get the list of hosts
open( CONFIG, $configFile) || die "Unable to open file!!!";
@cData = <CONFIG>;
close CONFIG;

my @filelist;
my $i = 0;

sub getFiles
{
	my $hostname = shift;
	my $username = shift;
	my $password = shift;
	my $dropLoc  = shift;
	my $file = shift;
	
	my $scpe = Net::SCP::Expect->new (
						'host' => ${hostname},
						'password' => ${password},
						'user' => ${username},
						'timeout' => 15
					 );


       eval { $scpe->scp("${hostname}:${file}","${dropLoc}/${hostname}"); };

	if ( $@ )
	{
		print $@ . "\n";
	}

}


foreach $Line (@cData)
{
	if ( !($Line =~ /#/) )
	{
		#Split the records in the file into usable information
        	@LData = split( /\|/,${Line});
        	$hostname=$LData[0];
        	$username=$LData[1];
        	$password=$LData[2];
		
		my $filelist;

		$filelist='ns_sys_config';

		if ( (chomp($hostname)) )
		{	
			exit(0);
		}
		else
		{
			if (! -d "${dumpLoc}" )
			{
				mkdir ( "${dumpLoc}" ) || die "Unable to create host directory !!!!";
			}
		}

		getFiles ( $hostname, $username, $password, "${dumpLoc}", $filelist );		

	}
}


