#!/usr/bin/perl

use warnings "all";

use Net::SSH::Expect;
use File::Path;

$configFile="/usr/local/sbin/css-config.list";
$dumpLoc="/data/network_configs/css/";

if (! -e $configFile)
{
        print "Error missing configuration file: $configFile \n";
        exit(0);
}

if (! -d $dumpLoc )
{
        mkpath("$dumpLoc") || die("Could not create directory: $dumpLoc");
}

#Open config file a get the list of hosts
open( CONFIG, $configFile) || die "Unable to open file!!!";
@cData = <CONFIG>;
close CONFIG;

foreach $Line (@cData)
{
	#Split the records in the file into usable information
	@LData = split( /\|/,${Line});
	$hostname=$LData[0];
	$username=$LData[1];
	$password=$LData[2];

	if ( (chomp($hostname)) )
        {		
        	exit(0);
	}
	
	#Open dump file
        $outfile="${dumpLoc}${hostname}";
        open(OUTFILE, ">$outfile") or die "Unable to open file $outfile for output!!!"; #open file for switch output

	#Prepare to login
        my $ssh = Net::SSH::Expect->new (
                                            'host' => $hostname,
					    'raw_pty' => 1
                                        );
        eval { $ssh->run_ssh(); };
	
	if ($@ || defined ($error))
	{

		print "ERROR: ${@} ";
		$error="true";
	}
	else
	{	
		#send login information
		$ssh->waitfor('Username:\z',10) or print "Unable to username prompt. \n";
		eval { $ssh->send("$username"); };
		
		if ($@ || defined ($error) || defined ($error) )
		{
			print "ERROR: ${@} ";
		}

         	$ssh->waitfor('Password:\z',10) or print "Unable to password prompt. \n";	
		eval { $ssh->send("$password"); };        
        	
		if ($@ || defined ($error))
                {
                        print "ERROR: ${@} ";
                }


		#set the terminal length high to prevent pauses in output
		$ssh->waitfor('#\s\z',10);
		eval {($ssh->send("terminal length 50000"));}; 

		if ($@ || defined ($error))
                {
                        print "ERROR: ${@} ";
                }

      		eval {$ssh->send("show run"); };
		if ($@ || defined ($error))
                {
                        print "ERROR: ${@} ";
                }

		while ( defined ($line = $ssh->read_line()) )
                {

			if ( !($line =~ m/^show run/ ) )
			{
				print OUTFILE $line;
			}
		}

		#close the ssh session 
       		$ssh->close();
	
		#close the file used to dump configuration
        	close (OUTFILE);
	}
}
