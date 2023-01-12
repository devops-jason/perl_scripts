#!/usr/bin/perl -w

##
##
#
# site_monitor.pl:
#	 is a script to test a list of URL's and report when one is down or slow.
#	 script also checks ping 
#
#	- Time::HiRes		is required for ping
#	- Net::Ping		is required for ping
#	- LWP::UserAgent	is required to test http
# 	- Crypt::SSLeay		and openssl are required to test https
#	- Getopt::Std		is required for verbose and help options
##
##

use warnings;
use LWP::UserAgent;
use Getopt::Long;
use Time::HiRes;
use Net::Ping;
use XML::Simple;
use File::Path qw(mkpath);
use Data::Dumper;

## NEEDED TO SUPPORT NEW FEATURE FOR NOTIFICATION OF ENV DISABLED ##
use File::stat;
use File::Basename;

##############
# EMAIL CONFIG
my $red_email;
my $yellow_email;
##############


sub readConfig 
{
		
		my $XS = XML::Simple->new();
		my $config = $_[0];
		my $configData;

		if ( $config && -f $config && -r $config && !(-z $config ) )
		{
			my $configData = eval { $XS->XMLin($config); };

			if ( $@ )
			{
				print $@ . "\n";
				return undef;
			}
			else
			{
				return $configData;
			}
		}
		else
		{
			print "Error: Unable to read file $config!\n\n";
			return undef;
		}

}

			
		
		

sub validIP
{
	
	if( $_[0] =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)/ )
	{
 
    		if($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255)
    		{
			return 1;
		}
    		else
    		{
			return 0;
		}
	}
	else
	{
		return 0;
	}
}

our @errors;

my $smonConfig		= "/data/site_monitor/etc/site_monitor_ng.xml";
my $smonConfigData;

my ($url, $email);
my $debug		= "";
my $verbose		= "";
my $userConfigFile	= "";
my $localtime		= localtime;
my $cmdlinemode		= 0;
my $testtype		= "";
my $notifytype		= "EMAIL";
my $cmdlinetarget	= "";
my $dontlog		= 0 ;
my ($day,$month,$date,$hour,$year) = split /\s+/,scalar localtime;

my @list;

GetOptions(
	    #'target=s'=> \$cmdlinetarget,
	    'verbose' => \$verbose,
	    'debug' => \$debug,
	    'config=s' => \$userConfigFile
	);

if ( $verbose )
{
	$verbose="true";
}

if ( $debug )
{
	$debug="true";
	$verbose="true";
}


if ( $userConfigFile )
{
	if ( -r $userConfigFile )
	{
 		$smonConfig = $userConfigFile;
	}
}
else
{
	if ( !( -r $smonConfig ) || -z $smonConfig || !( -f $smonConfig ) )
	{
		print "\nError: Unable to open $userConfigFile\nExiting!\n";
		exit ( 100 );
	}
}

			
#if ( !($cmdlinetarget) )
#{
#
#	if (-e $output_file) 
#	{
#   		open(OUT,">> $output_file") or die("Cant open exist file $output_file for append $!");
#	}
#	else
#	{
#		open(OUT,"> $output_file") or die("Cant open new file $output_file for writting $!");
#	}
#
#}
#else
#{
#	$verbose = "true";
#	$dontlog=1;
#		
#	if ( $cmdlinetarget )
#	{
#		my $error=0;
#		
#        	if ( $cmdlinetarget =~ m/^htt(p|ps):\/\// )
#        	{
#			$testtype="GET";
#			$notifytype="EMAIL";
#			$list[0]="${testtype}:::${notifytype}:::${cmdlinetarget}";
#		}
#		else
#		{
#			if ( validIP($cmdlinetarget) )
#			{
#				$testtype="PING";
#				$notifytype="EMAIL";
#				$list[0]="${testtype}:::${notifytype}:::${cmdlinetarget}";
#			}
#			else
#			{
#				print "Target not supported!\n";
#			}
#		}
#	}
#
#	else
#	{
#		print "Usage: $0 --target=\"[url]\"\n";
#		exit (1);
#	}
#			
#}			


$smonConfigData = readConfig ( $smonConfig );

if ( !( $smonConfigData ) )
{
	print "\nError: Problem reading file $smonConfig\nExiting!\n";
	exit ( 101 );
}


if ( $smonConfigData->{'config'}->{'verbose'} =~ m/^TRUE$/i )
{
	$verbose = "true";
}
else
{
	if ( !($verbose) )
	{
		$verbose = "false";
	}
}

if ( $smonConfigData->{'config'}->{'debug'} =~ m/^TRUE$/i )
{
	$debug = "true";
}
else
{
	if ( !($debug) )
	{
		$debug = "false";
	}
}


if ( $smonConfigData->{'config'}->{'logging'}->{'dir'} )
{
	if ( !( -d $smonConfigData->{'config'}->{'logging'}->{'dir'} ) )
	{
		if ( !( mkpath ( $smonConfigData->{'config'}->{'logging'}->{'dir'} ) ) )
		{
			print "Error: Unable to create logging directory " . $smonConfigData->{'config'}->{'logging'}->{'dir'} . "!\nLogging disabled!\n";
			$dontlog = 1;
		}
		else
		{
			print "Created logging directory " . $smonConfigData->{'config'}->{'logging'}->{'dir'} . ".\n";
		}
		
	}
}

if ( $smonConfigData->{'config'}->{'notification'}->{'yellow'} )
{
	$yellow_email = $smonConfigData->{'config'}->{'notification'}->{'yellow'};
}
else
{
	$yellow_email = 'root';
}

if ( $smonConfigData->{'config'}->{'notification'}->{'red'} )
{
	$red_email = $smonConfigData->{'config'}->{'notification'}->{'red'};
}
else
{
	$red_email = 'root';
}

my $system = $smonConfigData->{'config'}->{'system'}->{'name'};
my $udp_response_limit = $smonConfigData->{'config'}->{'responses'}->{'udp'}->{'limit'};
my $tcp_response_limit = $smonConfigData->{'config'}->{'responses'}->{'tcp'}->{'limit'};
my $http_response_limit = $smonConfigData->{'config'}->{'responses'}->{'http'}->{'limit'};
my $ping_response_limit = $smonConfigData->{'config'}->{'responses'}->{'ping'}->{'limit'};
my $ping_timeout = $smonConfigData->{'config'}->{'responses'}->{'ping'}->{'timeout'};
my $ping_timetowait = $smonConfigData->{'config'}->{'responses'}->{'ping'}->{'wait'};
my $ping_maxiteration = $smonConfigData->{'config'}->{'responses'}->{'ping'}->{'iterations'};
my $up = $smonConfigData->{'config'}->{'messages'}->{'up'};
my $down = $smonConfigData->{'config'}->{'messages'}->{'down'};
my $slow = $smonConfigData->{'config'}->{'messages'}->{'slow'};
my $disableTimeMin;

if ( $smonConfigData->{'config'}->{'disabletimemin'} )
{
	if ( $smonConfigData->{'config'}->{'disabletimemin'} =~ m/^(\d+)$/ )
	{
		$disableTimeMin = $smonConfigData->{'config'}->{'disabletimemin'} * 60;
	}
	else
	{
		$disableTimeMin = 900;
	}
}


my $output_file;
my $site_monitor_home;

if ( $smonConfigData->{'config'}->{'basePath'} )
{
	if ( -d $smonConfigData->{'config'}->{'basePath'} )
	{
		$site_monitor_home = $smonConfigData->{'config'}->{'basePath'};
	}
	else
	{
		$site_monitor_home = "/data/site_monitor";
	}
}
else
{
	$site_monitor_home = "/data/site_monitor";
}

if ( $smonConfigData->{'config'}->{'file'} )
{
	$output_file = $site_monitor_home . $smonConfigData->{'config'}->{'file'} . "_${month}_${date}_${year}.log";
}
else
{
	 $output_file = $site_monitor_home."/log/site_monitor_${month}_${date}_${year}.log";
}

if ( !($cmdlinetarget) )
{

        if (-e $output_file)
        {
                open(OUT,"| /usr/local/sbin/dateFilter.pl >> $output_file") or die("Cant open exist file $output_file for append $!");
        }
        else
        {
                open(OUT,"| /usr/local/sbin/dateFilter.pl > $output_file") or die("Cant open new file $output_file for writting $!");
        }

}
else
{
        $verbose = "true";
        $dontlog=1;

        if ( $cmdlinetarget )
        {
                my $error=0;

                if ( $cmdlinetarget =~ m/^htt(p|ps):\/\// )
                {
                        $testtype="GET";
                        $notifytype="EMAIL";
                        $list[0]="${testtype}:::${notifytype}:::${cmdlinetarget}";
                }
                else
                {
                        if ( validIP($cmdlinetarget) )
                        {
                                $testtype="PING";
                                $notifytype="EMAIL";
                                $list[0]="${testtype}:::${notifytype}:::${cmdlinetarget}";
                        }
                        else
                        {
                                print "Target not supported!\n";
                        }
                }
        }

        else
        {
                print "Usage: $0 --target=\"[url]\"\n";
                exit (1);
        }

}

my @envdefs;

if ( ref ($smonConfigData->{'config'}->{'envdefs'}->{'file'}) eq  "ARRAY" )
{
	@envdefs = @{ $smonConfigData->{'config'}->{'envdefs'}->{'file'} };
}
else
{
	$envdefs[0] = $smonConfigData->{'config'}->{'envdefs'}->{'file'};
}

my @configs;
my $i=0;

foreach my $file ( @envdefs )
{
	if ( readConfig ( $file ) )
	{
		$configs[$i] = readConfig ( $file );
		$i++;
	}
	else
	{
		print "Can't read xml file $file. Skipping!\n";
	}
	
}

my @cflist;
$i = 0;

my $j = 0;


foreach my $conf ( @configs )
{

	if ( $j <= @envdefs )
	{
		my $disableFile = $envdefs[$j] . ".disable";
		my $notifyFile = "/tmp/" . basename ( $envdefs[$j] ) . ".notify";
		my $cEnvironment;

		if ( $conf->{'name'} && !( ref ( $conf->{'name'} ) ) )
		{
			$cEnvironment = $conf->{'name'};
		}
		else
		{
			$cEnvironment = "unknown";
		}

		if ( -f $disableFile )
		{
			if ( time() < stat ( $disableFile )->mtime )
			{
				print OUT "Clock skew detected!!!\n Please check the clock and file modification times.\n";
				if ( $verbose || $debug )
				{
					print OUT "Clock skew detected!!!\nPlease check the clock and file modification times.\n";
					
					if ( $debug || $verbose )
					{
						print "Clock skew detected!!!\nPlease check the clock and file modification times.\n";
					}
					SendNotification ( "Clock skew detected on ${system}!","Clock skew detected please check ${system}'s clock and file modification times.");
				}
				exit (123);
			}
			else
			{
				if ( time() - stat ( $disableFile )->mtime <= $disableTimeMin)
				{
					if ( -f $notifyFile )
					{
						print OUT "Notification file: ${notifyFile} detected not sending notification of disabled environment!\n";
						
						if ( $debug || $verbose )
						{
							print "Notification file: ${notifyFile} detected not sending notification for disabled environment: ${cEnvironment}!\n";
						}
					}
					else
					{
						SendNotification ( "${cEnvironment} environment disabled for " . ($disableTimeMin/60) . " minutes", "${cEnvironment} has been disabled for maintenance and will" .
								   " be re-enabled in " . ( $disableTimeMin / 60 ) . " minutes." );


						print OUT "Sending disabled environment notification for: $cEnvironment!\n";
						
						if ( $debug || $verbose )
						{
							print "Sending disabled environment notification for: $cEnvironment!\n";
						}

						open ( FILE, ">${notifyFile}" ) or print OUT "Unable to create notification file: ${notifyFile}!\n";
						
						if ( fileno ( FILE ) )
						{
							close ( FILE );
						}
						else
						{
							if ( $debug || $verbose )
							{
								print "Unable to create notification file: ${notifyFile}!\n";
							}
						}
					}
					$j++;
					next;
				}
				else
				{
					if ( -f $notifyFile )
					{
						SendNotification ( "${cEnvironment} environment re-enabled after " . ($disableTimeMin/60) . " minutes", "${cEnvironment} has been re-enabled after the maintenance window was reached." );

						print OUT "Notification file: ${notifyFile} detected outside disable window removing!\n";
						print OUT "Sending notification of re-enabled environment: $cEnvironment\n!";

						if ( $debug || $verbose )
						{
							print "Notification file: ${notifyFile} detected outside disable window removing!\n";
                                                	print "Sending notification of re-enabled environment: $cEnvironment!\n";
						}
						
						unless ( unlink $notifyFile )
						{
							print OUT "Unable to remove notification file: ${notifyFile}\n";
						
							if ( $debug || $verbose )
							{
								print "Unable to remove notification file: ${notifyFile}\n";
							}
						}
						
						unless ( unlink $disableFile )
						{
							print OUT "Unable to remove disable file: ${disableFile}\n";
							
							if ( $debug || $verbose )
							{
								print "Unable to remove disable file: ${disableFile}\n";
							}
						}
					}
				}
			}
		}
	}

	$j++;
	

	if ( ref( $conf->{'targets'}->{'target'} ) eq "ARRAY" )
	{
		foreach my $target ( @{ $conf->{'targets'}->{'target'} } )
		{
			my $conv;
	
			if ( $target->{'status'} )
			{
				
				if ( $target->{'status'} =~ m/^(disabled|off|stop|0)$/i )
				{
					next;
				}
			}
				

			if ( $target->{'test-type'} )
			{
				$conv = $target->{'test-type'} . ":::";
			}
			else
			{
				$conv = "UNSUPPORTED:::";
			}
			
			if ( $target->{'notification'} )
			{
				if ( $target->{'notification'} =~ m/^(PAGE|EMAIL)$/i )
				{
					$conv .= $target->{'notification'} . ":::";
				}
				else
				{
					$conv .= "EMAIL:::";
				}
			}
			else
			{
				$conv .= "EMAIL:::";
			}

			if ( $target->{'prefix'} && $target->{'host'} && $target->{'path'} && $target->{'port'} )
			{
				if ( $target->{'port'} eq "443" || $target->{'port'} eq "80" )
				{
					$conv .= $target->{'prefix'} . $target->{'host'} . $target->{'path'} . ":::";
				}
				else
				{
					$conv .= $target->{'prefix'} . $target->{'host'} . ":" . $target->{'port'} . $target->{'path'} . ":::";
				}
			}
			elsif ( $target->{'test-type'} !~ m/(GET|PUT)/i && $target->{'host'} )
			{
				$conv .= $target->{'host'} . ":::";
			}
			else
			{
				$conv="";
			}

			if ( $target->{'host'} && $target->{'port'} && $target->{'test-type'} !~ m/(PING)/ )
			{
				if ( $target->{'authentication'} )
				{
					if ( $target->{'authentication'}->{'realm'} )
					{
						if ( $target->{'authentication'}->{'username'} )
						{
							if ( $target->{'authentication'}->{'password'} )
							{
								$conv .= $target->{'host'} . ":::" . $target->{'port'} . ":::" . $target->{'authentication'}->{'realm'} . ":::" . $target->{'authentication'}->{'username'} . ":::" . $target->{'authentication'}->{'password'} . ":::";
							}
						}
					}
				}
				else
				{
					$conv .= "#NA#:::#NA#:::#NA#:::#NA#:::#NA#:::";
				}
			}
			elsif ( $target->{'host'} && $target->{'test-type'} =~ m/PING/ )
			{
				$conv .= $target->{'host'} . ":::#NA#:::#NA#:::#NA#:::#NA#:::";
			}

			if ( $target->{'http-headers'}->{'header'} )
			{
				if ( @{$target->{'http-headers'}->{'header'}} >= 1 )
				{
					my $nHeader;
					my $j=0;

					if ( @{$target->{'http-headers'}->{'header'}} > 1 )
					{
						foreach my $tHeader ( @{$target->{'http-headers'}->{'header'}} )
						{
							if ( $j > 1 )
							{
								$nHeader =  $tHeader->{'name'} . "=>" . $tHeader->{'value'} ;
							}
							else
							{
								$nHeader .= ',' . $tHeader->{'name'} .  "=>" . $tHeader->{'value'} ;
							}
					
							$j++;
						}
					}
					else
					{
						$nHeader = $target->{'http-headers'}->{'header'}->{'header'}->{'name'} . "=>" . $target->{'http-headers'}->{'header'}->{'header'}->{'value'};
					}

					$conv .= $nHeader;
				}
				else
				{
					$conv .= "#NA#:::";
				}
			}
			else
			{
				$conv .="#NA#:::";
			}

		
			if ( $target->{'response'}->{'body'} )
			{
				$conv .= $target->{'response'}->{'body'} . ":::";
			}
			else
			{
				$conv .= "(.*):::";
			}			
				
			if ( $target->{'response'}->{'httpcode'} )
			{
				$conv .= $target->{'response'}->{'httpcode'} . ":::";
			}

			if ( $target->{'response'}->{'timeout'} )
			{
				if ( $target->{'response'}->{'timeout'} =~ m/(\d+)/ )
				{
					$conv .= $target->{'response'}->{'timeout'} . ":::";
				}
				else
				{
					$conv .= 10 . ":::";
				}
			}
			else
			{
				$conv .= 10 . ":::";
			}
	
			if ( $conv )
			{
				push ( @cflist, $conv );
			}

			$i++;
		}
	}
	else
	{
		my $target = $conf->{'targets'}->{'target'};

	        my $conv;
	
		if ( $target->{'status'} )
                {

			if ( $target->{'status'} =~ m/^(disabled|off|stop|0)$/i )
                        {
	                        next;
                        }
                }


             	if ( $target->{'test-type'} )
       	        {
                	$conv = $target->{'test-type'} . ":::";
                }
                else
                {
                	$conv = "UNSUPPORTED:::";
                }

                if ( $target->{'notification'} )
                {
          		if ( $target->{'notification'} =~ m/^(PAGE|EMAIL)$/i )
                        {
                         	$conv .= $target->{'notification'} . ":::";
                        }
                        else
                        {
                        	$conv .= "EMAIL:::";
                        }
               	}
               	else
		{
                	$conv .= "EMAIL:::";
           	}


                if ( $target->{'prefix'} && $target->{'host'} && $target->{'path'} && $target->{'port'} )
                {
                	$conv .= $target->{'prefix'} . $target->{'host'} . ":" . $target->{'port'} . $target->{'path'} . ":::";
              	}
               	elsif ( $target->{'test-type'} !~ m/(GET|PUT)/i && $target->{'host'} )
             	{
              		$conv .= $target->{'host'} . ":::";
             	}
             	else
              	{
             		$conv="";
          	}

         	if ( $target->{'host'} && $target->{'port'} && $target->{'test-type'} !~ m/(PING)/ )
             	{
            		if ( $target->{'authentication'} )
                 	{
                   		if ( $target->{'authentication'}->{'realm'} )
                         	{
                            		if ( $target->{'authentication'}->{'username'} )
                                	{
                                    		if ( $target->{'authentication'}->{'password'} )
                                             	{
							
                                           		$conv .= $target->{'host'} . ":::" . $target->{'port'} . ":::" . $target->{'authentication'}->{'realm'} . ":::" . $target->{'authentication'}->{'username'} . ":::" . $target->{'authentication'}->{'password'} . ":::";
                                             	}
                             		}
                             	}
                    	}
                    	else
                    	{
                    		$conv .= "#NA#:::#NA#:::#NA#:::#NA#:::#NA#:::";
                    	}
               	}
              	elsif ( $target->{'host'} && $target->{'test-type'} =~ m/PING/ )
            	{
         		$conv .= $target->{'host'} . ":::#NA#:::#NA#:::#NA#:::#NA#:::";
          	}

           	if ( $target->{'http-headers'}->{'header'} )
            	{
             		if ( @{$target->{'http-headers'}->{'header'}} >= 1 )
                   	{
                       		my $nHeader;
                              	my $j=0;

                         	if ( @{$target->{'http-headers'}->{'header'}} > 1 )
                            	{
                            		foreach my $tHeader ( @{$target->{'http-headers'}->{'header'}} )
                                	{
                                      		if ( $j > 1 )
                                    		{
                                          		$nHeader =  $tHeader->{'name'} . "=>" . $tHeader->{'value'} ;
                                               	}
                                              	else
                                              	{
                                                	$nHeader .= ',' . $tHeader->{'name'} .  "=>" . $tHeader->{'value'} ;
                                                }

                                          	$j++;
                                     	}
                            	}
                             	else
                           	{
                                	$nHeader = $target->{'http-headers'}->{'header'}->{'header'}->{'name'} . "=>" . $target->{'http-headers'}->{'header'}->{'header'}->{'value'};
                              	}

                            	$conv .= $nHeader;
                     	}
                    	else
                   	{
                       		$conv .= "#NA#:::";
                       	}
            	}
              	else
                {
                	$conv .="#NA#:::";
                }


            	if ( $target->{'response'}->{'body'} )
            	{
           		$conv .= $target->{'response'}->{'body'} . ":::";
              	}
             	else
           	{
            		$conv .= "(.*):::";
             	}

     	        if ( $target->{'response'}->{'httpcode'} )
           	{
              		$conv .= $target->{'response'}->{'httpcode'} . ":::";
            	}

            	if ( $target->{'response'}->{'timeout'} )
             	{
         		if ( $target->{'response'}->{'timeout'} =~ m/(\d+)/ )
               		{
                 		$conv .= $target->{'response'}->{'timeout'} . ":::";
                	}
                       	else
                        {
                        	$conv .= 10 . ":::";
                       	}
              	}
             	else
               	{
             		$conv .= 10 . ":::";
           	}

              	if ( $conv )
            	{
              		push ( @cflist, $conv );
                }

       		$i++;
    	}
}
		
		


#exit (0);
@list = @cflist;

main();

sub main {
	foreach my $line ( @list ) {
		my ($response_limit,$total_time,$retval);
		next if $line =~ /^#.*$/;
		next if $line =~ /^\s+$/;
		chomp $line;
		my ($test,$type,$url,$host,$port,$realm,$user,$pass,$headers,$body,$httpcode,$timeout) = split(/:::/, $line);

		if ($test eq "PING") {
			$retval = ping("$url","$type","$timeout");
			$response_limit = $ping_response_limit;
		} elsif ($test eq "TCP") {
			$retval = tcp_chk("$url","$type","timeout");
			$response_limit = $tcp_response_limit;
		} elsif ($test eq "UDP") {
			$retval = udp_chk("$url","$type");
			$response_limit = $udp_response_limit;
		} elsif ($test eq "GET") {
			$retval = check("$url","$type","$host","$port","$realm","$user","$pass","$headers","$body","$httpcode","$timeout");
			$response_limit = $http_response_limit;
		} elsif ($test eq "PUT") {
			$retval = put_check("$url","$type");
			$response_limit = $http_response_limit;
		} else {
			print "Error: Test type not supported";
			exit;		
		}

		my ($status,$start,$time,$return_status) = split(/:::/, $retval);

		if ($test eq "PING") {
			(undef, $total_time) = split(/:/, $return_status); # Result of timer
			chomp $total_time;
		} else {
			$total_time = ($time - $start); # Result of timer
		}

		if ($status eq $up) {
			if ($response_limit && ($response_limit <= $total_time)) {
				LogIt("$slow","$total_time","$url","$type","$return_status","$test");
		       	} else {
    				my ($out_format,$target);

				if ($test eq "PING") {
					$target = "$test $url";
		             		$out_format = sprintf "| %-60.60s %-10s %-20s |\n", 
    		             		$target, "ACCESSED", "Response $total_time milliseconds on 1st try";
				} else {
					$target = "$test $url";
		             		$out_format = sprintf "| %-60.60s %-10s %-20s |\n", 
    		             		$target, "ACCESSED", "Response $total_time seconds on 1st try";
				}

				if ( !$dontlog )
				{
					print OUT $out_format; # write to file
				}

				if ($verbose eq "true") {
          				print $out_format; # write to stdout 
				}
			}
		} else { 
			#SECOND TEST
			sleep 3;

			if ($test eq "PING") {
				$retval = ping("$url","$type","$timeout");
				$response_limit = $ping_response_limit;
			} elsif ($test eq "TCP") {
				$retval = tcp_chk("$url","$type","$timeout");
				$response_limit = $tcp_response_limit;
			} elsif ($test eq "UDP") {
				$retval = udp_chk("$url","$type");
				$response_limit = $udp_response_limit;
			} elsif ($test eq "GET") {
				$retval = check("$url","$type","$host","$port","$realm","$user","$pass","$headers","$body","$httpcode","$timeout");
				$response_limit = $http_response_limit;
			} elsif ($test eq "PUT") {
				$retval = put_check("$url","$type");
				$response_limit = $http_response_limit;
			} else {
				print "Error: Test type not supported";
				exit;		
			}

			my ($status,$start,$time,$return_status) = split(/:::/, $retval);

			if ($test eq "PING") {
				(undef, $total_time) = split(/:/, $return_status); # Result of timer
				chomp $total_time;
			} else {
				$total_time = ($time - $start); # Result of timer
			}

			if ($status eq $up) {
				if ($response_limit && ($response_limit <= $total_time)) {
					LogIt("$slow","$total_time","$url","$type","$return_status","$test");

			       	} else {
    					my ($out_format, $target);
					if ($test eq "PING") {
						$target = "$test $url";
			        		$out_format = sprintf "| %-60.60s %-10s %-20s |\n", 
    			        		$target, "ACCESSED", "Response $total_time milliseconds on 2nd try";
					} else {
						$target = "$test $url";
			        		$out_format = sprintf "| %-60.60s %-10s %-20s |\n", 
    			        		$target, "ACCESSED", "Response $total_time seconds on 2nd try";
					}

					if ( !($dontlog) )
					{
          					print OUT $out_format; # write to file
					}
					if ($verbose eq "true") {
          					print $out_format; # write to stdout 
					}
				}
			} else {
				#THIRD TEST
				sleep 3;
				if ($test eq "PING") {
					$retval = ping("$url","$type","$timeout");
					$response_limit = $ping_response_limit;
				} elsif ($test eq "TCP") {
					$retval = tcp_chk("$url","$type","$timeout");
					$response_limit = $tcp_response_limit;
				} elsif ($test eq "UDP") {
					$retval = udp_chk("$url","$type");
					$response_limit = $udp_response_limit;
				} elsif ($test eq "GET") {
					$retval = check("$url","$type","$host","$port","$realm","$user","$pass","$headers","$body","$httpcode","$timeout");
					$response_limit = $http_response_limit;
				} elsif ($test eq "PUT") {
					$retval = put_check("$url","$type");
					$response_limit = $http_response_limit;
				} else {
					print "Error: Test type not supported";
					exit;		
				}

				my ($status,$start,$time,$return_status) = split(/:::/, $retval);
	
				if ($test eq "PING") {
					(undef, $total_time) = split(/:/, $return_status); # Result of timer
					chomp $total_time;
				} else {
					$total_time = ($time - $start); # Result of timer
				}
	
				if ($status eq $up) {
					if ($response_limit && ($response_limit <= $total_time)) {
						LogIt("$slow","$total_time","$url","$type","$return_status","$test");
	
					} elsif ($response_limit && ($total_time < $response_limit)) {
    						my ($out_format, $target);
						if ($test eq "PING") {
							$target = "$test $url";
				        		$out_format = sprintf "| %-60.60s %-10s %-20s |\n", 
    				        		$target, "ACCESSED", "Response $total_time milliseconds on 3rd try";
						} else {
							$target = "$test $url";
				        		$out_format = sprintf "| %-60.60s %-10s %-20s |\n", 
    				        		$target, "ACCESSED", "Response $total_time seconds on 3rd try";
						}
						if ( !($dontlog) )
						{
							print OUT $out_format; # write to file
						}
						if ($verbose eq "true") {
       	   						print $out_format; # write to stdout 
						}
					}

				} else {
					LogIt("$down","$total_time","$url","$type","$return_status","$test");
				}
			}
		}
	}
}

sub check {  
    my $target = $_[0];
    my $type   = $_[1];
    my $host	= $_[2];
    my $port    = $_[3];
    my $realm	= $_[4];
    my $user    = $_[5];
    my $pass    = $_[6];
    my $headers = $_[7];
    my $rbody    = $_[8];
    my $httpcode = $_[9];
    my $timeout = $_[10];

        my $ua = LWP::UserAgent->new;
	#$ua->timeout(15);

	if ( $timeout =~ m/^(\d+)$/ )
	{
		$ua->timeout($timeout);
	}
	else
	{
		$ua->timeout(30);
	}

        $ua->agent("iControl site monitor from $system");
		
		if ($debug eq "true" && $host && $port && $realm && $user && $pass )
		{
			$ua->credentials($host . ":" . $port, $realm, $user, $pass);
			print STDERR "Inside ${target}\n";
		}
		elsif ( $debug eq "false" && $host && $port  && $realm && $user && $pass )
		{
			$ua->credentials($host . ":" . $port, $realm, $user, $pass);
		} 
              	else 
		{
			if ($debug eq "true") 
			{
				print STDERR "No Auth Entry\n";
			} 
		}

        my $req = HTTP::Request->new(GET => "$target");
	
	if ( $headers )
	{
		my @tHeader = split ( ',',$headers);
		
		foreach my $tsHeader ( @tHeader )
		{
	
			my ($head, $value ) = split ( '=>', $tsHeader );
			$req->header( $head => $value );
		}
			 
	}		
        # send request
        my $start = time;      # Start timer
        my $res = $ua->request($req);
        # check the outcome
	

        if ($res->is_success) {
		my $time = time;     # End timer

		my $return_status = $res->status_line; #GRAB STATUS CODE FROM XML FILE

		if ($debug eq "true")  {print STDERR "TARGET:  __${target}__\n";} 
		
			my $body =  $res->content;
			if ($debug eq "true")  {print STDERR "BODY:  __${body}__\n";} 
			if ($body !~ m/${rbody}/ ) {
				$return_status = "Response not: ${rbody} \n Response: \n $body";
	 			return "${down}:::${start}:::${time}:::${return_status}\n";	
			}
			else
			{
				if ( $debug eq "true" ) 
				{
					#print "UP: $up START: $start TIME: $time\n";
				}
			}

	 	return "${up}:::${start}:::${time}:::${return_status}\n";	

	} else {
		my $time = time;     # End timer
		my $return_status = $res->status_line;
		my $body =  $res->content;
		if ($debug eq "true")  {print STDERR "TARGET:  __${target}__\n";} 
		if ($debug eq "true")  {print STDERR "BODY:    __${body}__\n";} 
	 	return "${down}:::${start}:::${time}:::${return_status}\n";	
	}

}

sub tcp_chk {
my $target = $_[0];
my $type   = $_[1];
my $timeout = $_[2];

use Socket;

if ( $timeout !~ m/^(\d+)$/ )
{
	$timeout = 3;
}

	
my ($host,$port) = split(/:/, $target);
my $proto = getprotobyname('tcp');
my $iaddr = inet_aton($host);
my $paddr = sockaddr_in($port, $iaddr);
my $start = time;      # Start timer

socket(SOCKET, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";

eval {
	local $SIG{ALRM} = sub { die "timeout" };
	alarm($timeout);
	connect(SOCKET, $paddr) || error();
	alarm(0);
};

if ($@) {
	close SOCKET || die "close: $!";
	my $time = time;     # End timer
	my $return_status = "Port $port Open";
	return "${down}:::${start}:::${time}:::${return_status}\n";	
} else {
	close SOCKET || die "close: $!";
	my $time = time;     # End timer
	my $return_status = "Port $port Closed";
	return "${up}:::${start}:::${time}:::${return_status}\n";	
}

} #END tcp_check

sub ping {
	my $host = $_[0];
	my $type   = $_[1];
	my $timeout = $_[2];
        my $start = time;      # Start timer
	my $bytes = "8";
	my $maxduration = 0;
	my $i = 1; # simple iterator
	my %pings = ();

if ( $timeout )
{
	if ( $timeout !~ m/(\d+)/ )
	{
		$ping_timeout = 3;
	}
	else
	{
		$ping_timeout = $timeout;
	}
}
else
{
	$ping_timeout = 3;
}

# builds the ping object
my $p = Net::Ping->new("icmp", $ping_timeout, $bytes);
#HTTP_PING# $p->{port_num} = getservbyname("http", "tcp");
$p->hires();

while($i <= $ping_maxiteration)
{
	# build timestamp
	my ($s, $m, $h, $day, $month, $yearoffset, $dow, $doy, $dsl) = localtime();
	$month++;
	$year = 1900 + $yearoffset;
	
	# do ping
	my ($ret, $duration, $ip) = $p->ping($host);

	# check results
	if (($ret) and ($ret==1)) {
		$duration *= 1000;
		$pings{$i} = "up";
		$duration = sprintf("%.0f", $duration);

		if ($duration > $maxduration) {
			$maxduration = "$duration";
		}
	} else {
		$pings{$i} = "down";
	}
	
	sleep($ping_timetowait) if ($i != "3");

	$i++;
}

# close ping object and the output file
$p->close();

chomp $maxduration;

if (($pings{1} =~ /^up/) and ($pings{2} =~ /^up/) and ($pings{3} =~ /^up/)) {

	my $time = time;     # End timer
	my $return_status = "Host Up:$maxduration";
	return "${up}:::${start}:::${time}:::${return_status}\n";	

} elsif (($pings{1} =~ /down/) and ($pings{2} =~ /down/) and ($pings{3} =~ /down/)) {

	my $time = time;     # End timer
	my $return_status = "Host Down:000";
	return "${down}:::${start}:::${time}:::${return_status}\n";	

} elsif (($pings{1} =~ /(up)|(down)/) or ($pings{2} =~ /(up)|(down)/) or ($pings{3} =~ /(up)|(down)/)) {

	my $time = time;     # End timer
	my $return_status = "Packet Loss Experienced:$maxduration";
	return "${slow}:::${start}:::${time}:::${return_status}\n";	

}

}

sub LogIt {
##LogIt("$slow","$total_time","$url","$type","$return_status","$test");
    my $status		= $_[0];
    my $time		= $_[1];
    my $target		= $_[2];
    my $type		= $_[3];
    my $return_status	= $_[4];
    my $test		= $_[5];
    my $out_target	= "$test $target";
    my ($out_format, $subject);

	if ($test eq "PING") {
		$time = "$time milliseconds";
	} else {
		$time = "$time seconds";
	}

    if ($status eq "SLOW") {

	$out_format = sprintf "| %-60.60s %-10s %-20s |\n", $out_target, "SLOW", "Response $time";
	my $email		= "$yellow_email";
	$subject		= "$test Site Slow";
	my $message		= "$subject: $time to load\n";

	SendEmail("$target","$email","$subject","$message");

	if ( !($dontlog) )
	{
		print OUT $out_format; # write to file
	}
	if ($verbose eq "true") {
       		print $out_format; # write to stdout 
	}

    } else { # DOWN send page and email

	chomp ( $return_status );

	my $out_format = sprintf "| %-60.60s %-10s %-20s |", $out_target, "DOWN", "After 3 tests";

	$out_format = $out_format . "\n" . $return_status . "\n";
	if ( $type =~ /page/i ) {
		$email		= "$yellow_email,$red_email";
	} elsif ( $type =~ /email/i ) {
		$email		= "$yellow_email";
	} else {
		$email		= "$yellow_email,$red_email";
	}

	$subject		= "$test Site Down";

	if ( $return_status =~ /bad hostname/i ) {
		$email          = "$yellow_email";
		$subject	= "$test Site Down - DNS Failure ?";
	}

	my $message		= "${subject} after 3 tests: ${return_status}";
	SendEmail("$target","$email","$subject","$message");
	
	if ( ! ( $dontlog ) )
	{
		print OUT $out_format; # write to file
	}
	if ($verbose eq "true") {
       		print $out_format; # write to stdout 
	}
    }
}

sub SendEmail {
my $target 	= $_[0];
my $email 	= $_[1];
my $subject 	= $_[2];
my $message 	= $_[3];
my $mail_to	= "$email";
my $mail_from	= 'sitemon@' . $system;

#/usr/sbin/sendmail
my $mailcmd    = "/usr/sbin/sendmail -t -f $mail_from";
my $mess      .= "Subject: $subject\n";
$mess      .= "To:  $mail_to\n";
$mess      .= "From:  $mail_from\n";

open(MAIL,"| $mailcmd") || die "Can't open mail command\n";
print MAIL "$mess\n";
print MAIL "$message \n $target\n";
close(MAIL);
}

sub SendNotification 
{
	my $subject = $_[0];
	my $message = $_[1];
	my $mail_to = "$red_email";
	my $mail_from	= 'sysmon@' . $system;


	my $mailcmd    = "/usr/sbin/sendmail -t -f $mail_from";
	my $mess      .= "Subject: $subject\n";
	$mess      .= "To:  $mail_to\n";
	$mess      .= "From:  $mail_from\n";

	open(MAIL,"| $mailcmd") || die "Can't open mail command\n";
	print MAIL "$mess\n";
	print MAIL "$message\n";
	close(MAIL);
}



