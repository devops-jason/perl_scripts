#!/usr/bin/perl 


use warnings;

use POSIX qw(strftime);

use IPC::System::Simple qw(capture);

open STDERR, '>/dev/null';

#IP Address to trace

$ipaddr = "66.32.54.99";
$maxMS = 90.0;

$error;

my $storeHop;

eval { @output = capture("traceroute ${ipaddr}"); };

if ($@)
{
	print "Error!!!";
}
else
{
	foreach (@output)
	{
		chomp ($_);
		
		@hop = split(" ", $_);
		$test = join("#" , @hop);
		@hop = split("#", $test);

		#$test .= "\n";
		#print $test;
	
		#print $hop[3] . " " . $hop[5] . " " . $hop[7]. "\n";
	
		if ( $hop[1] =~ /\*/ && $hop[2] =~ /\*/ && $hop[3] =~ /\*/ )
		{
			$storeHop .= "No Reachable ----->      " . $_ ."\n\n";
		}
		else
		{
			if ( $hop[3] =~ /\*/ || $hop[5] =~ /\*/ || $hop[6] =~ /\*/ || $hop[8] =~ /\*/ )
			{
				$storeHop .= "Reponse Problems ----->  " . $_ ."\n\n";
		
			}
			else
			{
				if ( $hop[5] =~ /[0-9].[0-9]/ )
				{
					if ($hop[5] > $maxMS )
					{
						 $storeHop .= "Response Slow ----->     " . $_ ."\n\n";
						 $error="true";
					}
					
				}
				
				if ( $hop[6] =~ /[0-9].[0-9]/  && $hop[6] > $maxMS && !($error =~"true") )
				{
						$storeHop .= "Response Slow ----->     " . $_ ."\n\n";
						$error="true";
                                }
				if ( $hop[8] =~ /[0-9].[0-9]/ && $hop[8] > $maxMS )				
				{
					$storeHop .= "Response Slow ----->     " . $_ ."\n\n";
					$error="true";
				}
				
				if (!($error =~"true"))
				{
					$storeHop .= (" " x 25) .$_ . "\n\n";
				}
					
				
			}
		}
	
	$error="";
	}	
	print $storeHop;
}
 


