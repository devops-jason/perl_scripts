#!/usr/bin/perl

use warnings "all";

use Net::SSH::Expect;
use File::Path;

$configFile="/usr/local/sbin/pix-config.list";

#.list File Format
##########################################
# hostname|username|password|enablepw
##########################################


$dumpLoc="/data/network_configs/pix/";

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

foreach $Line (@cData)
{
	if ( !($Line =~ /#/) )
	{ 
	        #Split the records in the file into usable information
       	 	@LData = split( /\|/,${Line});
        	$hostname=$LData[0];
        	$username=$LData[1];
        	$password=$LData[2];
        	$enablepw=$LData[3];

		if ( (chomp($hostname)) )
        	{
               		exit(0);
        	}

        	$outfile=$dumpLoc . $hostname;

		open(OUTFILE, ">$outfile") or die "Unable to open file $outfile for output!!!"; #open file for switch output

		my $ssh = Net::SSH::Expect->new (
        					    'host' => $hostname,
            					    'password' => $password,
            					    'user' => $username,
						    'timeout' => 15,
						    'raw_pty' => 1
            				);
		my $login_output = $ssh->login();
		if ($login_output =~ />/) 
                {
                        $ssh->send('enable');
                        $ssh->send($enablepw);

                }
		else
		{
			die "unable to get login prompt!!"
		}	

		$ssh->waitfor( '#\s\z', 10) or print "Unable to get enabled prompt\n";

                $ssh->send("show run");

                while ( defined ($line = $ssh->read_line()) )
                {

                        if ( !($line =~ m/show run/ ) )
                        {
                                $line =~ s/\r//g;
                                print OUTFILE $line . "\n";
                        }
                        if ( $line =~ m/^: end/ )
                        {
                                $ssh->close();
                                next;
                        }
                }        

	$ssh->close();	
	close (OUTFILE);
	}
}

