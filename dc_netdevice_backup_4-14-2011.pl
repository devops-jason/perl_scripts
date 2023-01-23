#!/usr/bin/perl

use warnings "all";

use File::Path;
use File::Basename;
use POSIX qw(strftime);
use IPC::System::Simple qw(capture);
use Net::SSH::Expect;

open STDERR, '>/dev/null';

#GLOBAL VARIABLES

my $emailAddr='sysadmin@icontrol.com';			 # notification email
my $sysName=`echo -n \`uname -n\``;					 # system name
my $backupLoc='/mnt/backup/network_dc_configs/';	 	 # Location of dc configs
my $remoteLoc='/data/network_configs/';			 # Location of remote config dump
my $curDate=`echo -n \`date "+%m-%d-%Y.%H_%M"\``;	 # Todays date (filename)
my $dirDate=`echo -n \`date "+%m-%d-%Y"\``;		 # Todays Directory Date (arch)		 
my $nipperTime=`echo -n \`date "+%R"\``;
my $minSize=2000;					 # 2Kb (roughly)
my %hasError;


my $url="https://polaris.icontrol.com/netconfigs/";

#Logging
my $logDir="/data/remote/";
my $curLog=`echo -n \`date "+%m"\``;
my $logFileName="NetConf-Backup-";


#Local Dirs required
my %locDirs = ( 'arch' => "archive/${dirDate}",
		'cur'  => "current"
	      ); 

my $archDir = "archive"; #Needed to check first run

#Admin Servers used and location
my %admServer = ( 
		  'jsv' => 'controlmon1',
	       	  'sjc' => 'admin1',
		  'pao' => 'polaris'
		 );
#Admin Servers user login required
my %remoteUser = ( 
		   'controlmon1' => 'root',
		   'admin1'	 => 'root',
		   'polaris'	 => 'root' 
		 );


#Remote Device Locations
my %remoteDirs = ( 
		   'css' => 'css',
		   'pix' => 'pix',
		   'sw' => 'switch',
		   'ssg' => 'ssg'
		  );

#Remote Device List Location
my %remoteLists = ( 
		    'css' => '/usr/local/sbin/css-config.list',
		    'pix' => '/usr/local/sbin/pix-config.list',
		    'switch'=> '/usr/local/sbin/switch-config.list',
		    'ssg' => '/usr/local/sbin/ssg-config.list'
		  );

#Remote executables that create config files
my %remoteBin = ( 
		  'css' => '/usr/local/sbin/css-config.pl',
		  'pix' => '/usr/local/sbin/pix-config.pl',
		  'switch' => '/usr/local/sbin/switch-config.pl',
		  'ssg'	=> '/usr/local/sbin/ssg-config.pl'
		);
	

#Store Device Files
my %devFiles;

#Check Previous
my %confPrev;

#Nipper args
my %nipperArg = ( 
		  'css' => '--css',
		  'pix' => '--asa',
		  'switch' => '--ios-catalyst',
		  'ssg' => '--screenos' );


sub LogReport
{
	
	my $logFile = $_[0];
	my $logData = $_[1];
	my $tstamp = strftime "%Y %b %d %a %H:%M:%S %Z", localtime;

	if (defined($logData) && defined($logFile) )
	{
		@lines = split ("\n", $logData);
		foreach (@lines)
		{
			$log .= "${tstamp} - $_ \n";
		}
		
		open ( LOG, ">> ${logDir}${logFile}" ) or die "Unable to open log file ${logDir}${logFile} : $!\n";
		print LOG $log;
		close ( LOG );
	}
}


#Check to ensure the directory structure exists
sub verifyDirs
{
	my %output;

	#Check the data center directoru and its subdirectories
	foreach $dataCenter ( keys (%admServer) )
	{
		$output{"${dataCenter}-out"} = "#" x 100 ."\n" ."Checking Directory Structure For ${dataCenter}: \n" . "#" x 100 ."\n";
         	$output{"${dataCenter}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		#Start from the basedir and and verify and create the others
		if(! -d "${backupLoc}")
		{
			$output{"${dataCenter}-out"} .= "Creating Directory: ${backupLoc} \n";
			eval { mkpath("${backupLoc}"); };
                	if ($@)
                	{
				$output{"${dataCenter}-out"} .= "${backupLoc}: Error Detected! See output below. \n";
                		$output{"${dataCenter}-err"}.= "Couldn't create ${backupLoc}: $@ \n";
                	}
                	else
                	{
                       		$output{"${dataCenter}-out"}.="Successfully created: ${backupLoc} \n\n";
                	}
		}
		else
		{
			$output{"${dataCenter}-out"}.="Directory : ${backupLoc} \t*OK*\n";
		}

		if ( -d "${backupLoc}${dataCenter}/" )
		{
			foreach $dir ( values( %locDirs ) )
			{
				if(! -d "${backupLoc}${dataCenter}/${dir}/" )
				{
					$output{"${dataCenter}-out"}.="Creating Directory: ${backupLoc}${dataCenter}/${dir}/\n";
					eval { mkpath("${backupLoc}${dataCenter}/${dir}/"); };
					if ($@)
					{
						  $output{"${dataCenter}-out"} .= "${backupLoc}${dataCenter}/${dir}/: Error Detected! See output below.  \n";
						  $output{"${dataCenter}-err"}.="Couldn't create ${backupLoc}${dataCenter}/${dir}/: $@ \n\n";
					}
					else
					{
						  $output{"${dataCenter}-out"}.="Successfully created: ${backupLoc}${dataCenter}/${dir}/ \n\n";				
					}
				}
				else
				{
					$output{"${dataCenter}-out"}.="Directory : ${backupLoc}${dataCenter}/${dir}/ \t*OK*\n";
				}
			}
		}
		else
		{
			$output{"${dataCenter}-out"}.="Creating Directory: ${backupLoc}${dataCenter}/\n";
			eval { mkpath("${backupLoc}${dataCenter}/" ); };
			if ($@)
			{
				$output{"${dataCenter}-out"} .= "${backupLoc}${dataCenter}/: Error Detected! See output below. \n";
                        	$output{"${dataCenter}-err"}.="Couldn't create ${backupLoc}${dataCenter}/: $@ \n\n";
                        }
                        else
                       	{
                                 $output{"${dataCenter}-out"}.= "Successfully created: ${backupLoc}${dataCenter}/ \n\n";
                        }

			foreach $dir ( values( %locDirs ) )
                        {
                        	$output{"${dataCenter}-out"}.="Creating Directory: ${backupLoc}${dataCenter}/${dir}/\n";
                                eval { mkpath("${backupLoc}${dataCenter}/${dir}/"); };
                                if ($@)
                                {
					$output{"${dataCenter}-out"} .= "${backupLoc}${dataCenter}/${dir}/: Error Detected! See output below. \n";
                                	$output{"${dataCenter}-err"}.="Couldn't create ${backupLoc}${dataCenter}/${dir}/: $@ \n\n";
                                }
                                else
                                {
                                	$output{"${dataCenter}-out"}.= "Successfully created: ${backupLoc}${dataCenter}/${dir}/ \n\n";
					
				}
                        }

		}
		
		
		$output{"${dataCenter}-err"}.= "\n";	
	
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n\n";
		if ($output{"${dataCenter}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dataCenter}-err"} .= "No Errors Detected\n\n";
		} 	
		LogReport("${logFileName}${curLog}.log", $output{"${dataCenter}-out"} . $output{"${dataCenter}-err"} );
	}

	return %output;
}

sub grabDeviceList
{
	my %output;
	my @lst;

	foreach $dc ( keys( %admServer ) )
	{
		 $output{"${dc}-out"} = "#" x 100 ."\n" ."Getting The List Of Devices For ${dc}: \n" . "#" x 100 ."\n";
		 $output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		if ( defined ( $remoteUser{$admServer{$dc}} ) )
		{
			$output{"${dc}-out"} .= "\nDevice List \n" . ("~" x 50 ) .  "\n";
			foreach $list ( keys (%remoteLists) )
			{
				$cmd="ssh " . $remoteUser{$admServer{$dc}} . "@" . $admServer{$dc} . " \"cat " . $remoteLists{$list} . " \| grep -v \"^#\" \|  cut --delimiter=\'\|\' --fields=1 \| tr \'\\n\' \' \' \"";
				eval {	@disp = capture ("${cmd}"); };
				
			
				if ( ($dc eq 'pao' || $dc eq 'sjc') && $list eq 'css' || $dc eq 'pao' && $list eq 'pix' )
				{
					next;
				}
				if ( $dc eq 'sjc' && $list eq 'ssg' || $dc eq 'jsv' && $list eq 'ssg' )
				{
					next;
				}

				if (!@disp)
				{
					$output{"${dc}-err"} .= "\n" . "Unable to get file: " . $remoteLists{$list} . " on " . $admServer{$dc}  . "\n\n";
				}
					 
				if ($@)
				{
					$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
				}
				else
				{
					$output{"${dc}-out"} .= $list  . ": \n\t" . ((!@disp)?"No Devices Detected!\n":join("\n\t",split(" ",join("",@disp)))) . "\n\n";	
					if( @disp )
					{
						$devFiles{"${dc}-${list}"} = join(" ", @disp);
					}
					
				}	
	
			}		
		}
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );	
	}
	return %output;
}	

sub initConfigRun
{
	my $output;
	
	foreach $dc ( keys( %admServer) )
	{

		$output{"${dc}-out"} = "#" x 100 ."\n" ."Transferring configs to " . $admServer{$dc} . " at ${dc}: \n" . "#" x 100 ."\n";
		$output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		if ( defined ( $remoteUser{$admServer{$dc}} ) )
		{
			foreach $bin (  values(%remoteBin) )
			{
				$output{"${dc}-out"} .= "\nExecuting ${bin} on " . $admServer{$dc} . " : ";
				$cmd="ssh " . $remoteUser{$admServer{$dc}} . "@" . $admServer{$dc} . " ${bin} ";
				eval {	@disp = capture ("${cmd}"); };

				if ($@ ) 
				{
					$output{"${dc}-out"} .= "Error - See the output below!!! \n";
					$output{"${dc}-err"} .= "Unable to execute: ${bin} on $admServer{$dc}\n\n";
				}
				else
				{
					$output{"${dc}-out"} .= "*DONE* \n";
				} 

			}
		}
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );
	} 

	return %output;
}

			
sub grabDeviceConfigs
{
	my %output;
	
	foreach $dc ( keys( %admServer ) )
	{
		 $output{"${dc}-out"} = "#" x 100 ."\n" ."Grabbing Device Configurations at ${dc}: \n" . "#" x 100 ."\n";
		 $output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		if ( defined ( $remoteUser{$admServer{$dc}} ) )
		{
		
			foreach $dType ( values(%remoteDirs) )
			{
				@curFiles =  split(" ",$devFiles{"${dc}-${dType}"});	
				foreach $cFile ( @curFiles )
				{
					$cmd="ssh " . $remoteUser{$admServer{$dc}} . "@" . $admServer{$dc} . " \"cat " . ${remoteLoc} .${dType} . "/" . ${cFile} . "\"";
					eval {	$devFiles{"${dc}-${cFile}"} = join("",capture ("${cmd}")); };
					
					$devFiles{"${dc}-${cFile}"} =~ s/\r//g;
	
					if ($@)
					{
						$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
					}
					else
					{
						$output{"${dc}-out"} .= "\n" . "Grabbing ${cFile}. \n";
					}
					
				}
			}
		}
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );	
	}

	return %output;
}

#Check to see if this is the first time.

sub getPrevious
{
	my %output;
	
	foreach $dc ( keys (%admServer) )	
	{
		$devFiles{"${dc}-numConfigs"} = 0; # Make sure variable is empty
		$devFiles{"${dc}-numReports"} = 0; # Make sure variable is empty

		$output{"${dc}-out"} = "#" x 100 ."\n" ."Checking For Previous Configurations For ${dc}: \n" . "#" x 100 ."\n";
 		$output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		$cmd="echo -n \`ls ${backupLoc}${dc}/". $locDirs{'cur'} . "\`";
		
		eval { $out = join(" ",capture(${cmd})); };

		if ($@)
		{
			$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
		}
		else
		{
			if ($out)
			{
				$confPrev{"${dc}-cur"}="true";
				@disp = split (" ", $out);
				foreach (@disp)
				{
					if ( $_ =~ /.html/)
					{
						$output{"${dc}-out"}.= "\nReport : " . $_ . "\n";
						$devFiles{"${dc}-numReports"} += 1;
					}
					else
					{
						$devFiles{"${dc}-numConfigs"} += 1;
						$output{"${dc}-out"}.= "\nConfig : " . $_ . "\n";
					}
					$confPrev{"${dc}-prev"} .=  $_ . " ";
				}
				
			}
			else
			{
				$confPrev{"${dc}-cur"}="false";
				$output{"${dc}-out"}.="No Previous Configuration!\n";
			
			}
		}
		if ( $devFiles{"${dc}-numReports"} != $devFiles{"${dc}-numConfigs"} )
		{
			if ($devFiles{"${dc}-numReports"} > $devFiles{"${dc}-numConfigs"} )
			{
				$output{"${dc}-err"}.="Received To Many Reports!!!\n";
				$output{"${dc}-out"}.="\nReports : ". $devFiles{'numReports'} . "\tConfigs : " . $devFiles{'numConfigs'} . "\n";
			}
			else
			{
				$output{"${dc}-err"}.="Not Enough Reports Received!!!\n";
				$output{"${dc}-out"}.="\nReports : ". $devFiles{"${dc}-numReports"} . "\tConfigs : " . $devFiles{"${dc}-numConfigs"} . "\n";
			}
		}
		else
		{
			$output{"${dc}-out"}.="\nReports : ". $devFiles{"${dc}-numReports"} . "\nConfigs : " . $devFiles{"${dc}-numConfigs"} . "\n\n";
		}
		
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );	
	}

	return %output;
}
		
sub saveConfigs
{
	foreach $dc ( keys( %admServer ) )
	{
		 $output{"${dc}-out"} = "#" x 100 ."\n" ."Saving Configurations For ${dc}: \n" . "#" x 100 ."\n";
		 $output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		if ( defined ( $remoteUser{$admServer{$dc}} ) )
		{
		
			foreach $dType ( values(%remoteDirs) )
			{
				@curFiles =  split(" ",$devFiles{"${dc}-${dType}"});	
				foreach $cFile ( @curFiles )
				{
					$file = "${backupLoc}${dc}/". $locDirs{'cur'} . "/" .  $cFile . ".${curDate}";
					
					open (COUT, ">${file}") || ($output{"${dc}-err"} .= "\n" . $! . "\n\n");
					
					$devFiles{"${dc}-${cFile}-file"} = ${file}; # Keep track of the file (prevents checking current)
 					
					print COUT $devFiles{"${dc}-${cFile}"}; 
					$output{"${dc}-out"} .= "\n" . "Saving Config : ${url}${dc}/". $locDirs{'cur'} . "/".${cFile}.".".${curDate}. "\n\n";
					$devFiles{"${dc}-${cFile}-len"} = length ($devFiles{"${dc}-${cFile}"}); # Get the Length of config in chars
					close (COUT);
					
					if ($devFiles{"${dc}-${cFile}-len"} < 3400 )
					{
						$output{"${dc}-err"} .= "\n" . basename($devFiles{"${dc}-${cFile}-file"}) . ": Too Small (Less than 3400 characters !!!!)" . "\n\n";
					}				
					
					#create nipper report
					if ( $dType eq "ssg" )
					{
						open TMP, ">/tmp/${dc}-${cFile}";
						print TMP $devFiles{"${dc}-${cFile}"};
						close TMP;
						my $notimportant = `scp /tmp/${dc}-${cFile} cmon1:/tmp/${dc}-${cFile}`;
						$cmd="ssh root\@cmon1 \"cat /tmp/${dc}-${cFile} | nipper ".$nipperArg{$dType}."\" ";
					}
					else
					{
						$cmd="echo \"" . $devFiles{"${dc}-${cFile}"} ."\" |ssh " . "root\@cmon1 \"nipper " . $nipperArg{$dType}. "\" ";					
					}
					
					eval {	$devFiles{"${dc}-${cFile}-web"} = join("\n",capture ("${cmd}")); };
					
					if ( $dType eq "ssg" )
					{
						my $dontcare = `rm -f /tmp/${dc}-${cFile}`;
						$dontcare = `ssh root\@cmon1 \"rm -f /tmp/${dc}-${cFile}\"`;
					}

					$nfile = "${backupLoc}${dc}/". $locDirs{'cur'} . "/" .  $cFile . "." . ${curDate}. ".html";
					open ( COUTWEB, ">${nfile}");
						
					if ($@)
					{
						$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
						$output{"${dc}-out"} .= "\n" . "Problem Saving Report For: " . $cFile . "." . ${curDate}. ".html" . "\n\n" ;
					}
					else
					{
						$output{"${dc}-out"} .= "\n" . "Saving Report : ${url}${dc}/". $locDirs{'cur'} . "/".${cFile}.".".${curDate}. ".html\n\n";
						$devFiles{"${dc}-${cFile}-web"} =~ s/<div class=\"reportdate\">(.*?)<\/div>/<div class=\"reportdate\"> $1 - ${nipperTime} <\/div>/g;

						print COUTWEB $devFiles{"${dc}-${cFile}-web"};
						
					}
					close ( COUTWEB );
					
					
					
				}
			}
		}
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );
	
	}
	return %output;
}

sub movePrevious
{
	my %output;
	my $archLen;
	my $archData;
	my $tmpM;
	foreach $dc ( keys( %admServer ) )
	{
		 $output{"${dc}-out"} .= "#" x 100 ."\n" ."Moving Previous Configs and Reports To ${dc}: \n" . "#" x 100 ."\n";
		 $output{"${dc}-err"} .= "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";

		if ( defined ( $admServer{$dc} ) )
		{
			if ($confPrev{"${dc}-cur"} =~ /false/)
			{
				$output{"${dc}-out"} .= "\nNo Previous Configurations - Checking for First Run\n";
				
				$cmd="ls -R ${backupLoc}${dc}/${archDir}";
		
				eval { @disp = capture(${cmd}); };

				if ($@)
				{
					$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
				}
				else
				{
					$archData = join (" ", @disp);
					$archLen = length ($archData);
					if ($archLen > 115 )
					{
						$output{"${dc}-out"}.= "\nError Detected!!! See Below For Details.\n";
						$output{"${dc}-err"} .= "Bad State Detected: No files in ${backupLoc}${dc}/" . $locDirs{'cur'} . "  and the archive is not empty!!! \n\n"
					}
					else
					{
						$confPrev{"${dc}-first"}="true";
						$output{"${dc}-out"}.="\nFirst Run Detected !!!!\n\n";
			
					}
				}
			}
			else
			{	
		
				@prevFiles =  split(" ",$confPrev{"${dc}-prev"});	
				foreach $pFile ( @prevFiles )
				{
					
					$tmpM = $pFile;
					$tmpM = `echo $tmpM | cut -d \".\" -f 2`;
					
					chomp ($tmpM);

					$cmd="echo -n \`mv -v ${backupLoc}${dc}/". $locDirs{'cur'} . "/" . $pFile . " ${backupLoc}${dc}/". $archDir . "/" . $tmpM ."/" . $pFile . "\`" ;	
					
					eval { @disp = capture(${cmd}); };

					if ($@)
					{
						$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
					}
					else
					{
						foreach $mFile ( @disp )
						{
							$output{"${dc}-out"} .= $mFile . "\n";
						}
					}
				
				}
			}
		}
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );	
	}

	return %output;
}


sub genDiffReport
{
	my %output;
	my $nodifference=1;
	my $count=0;

	foreach $dc ( keys( %admServer ) )
	{
		if ($confPrev{"${dc}-cur"} =~ /true/)
		{
		 	$output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		
		 	if ( defined ( $admServer{$dc} ) )
		 	{
		
				foreach $dType ( values(%remoteDirs) )
				{
					@curFiles =  split(" ",$devFiles{"${dc}-${dType}"});	
					foreach $cFile ( @curFiles )
					{
						
						@old = split(" ",$confPrev{"${dc}-prev"});
						foreach $oFile ( @old )
						{
							if ( $oFile =~ /${cFile}/ && !($oFile =~ /.html/) )
							{	
#"diff " . $devFiles{"${dc}-${cFile}-file"} ." ". "${backupLoc}${dc}/". $locDirs{'arch'} . "/${oFile} \| grep -v -x \"...c...\" \| grep -v \". ntp clock-period\" \| grep -v \"Generated on\""
								$cmd = "diff " . $devFiles{"${dc}-${cFile}-file"} ." ". "${backupLoc}${dc}/". $locDirs{'arch'} . "/${oFile} \| grep -v -x \"...c...\" \| grep -v \". ntp clock-period\" \| grep -v \"Generated on\" \| grep -v -x \".c.\" \| grep -v -x \"^---\" ";

								eval { $dif = join("\n", capture([0..5 ],${cmd})); };

								if ($@)
								{
									$output{"${dc}-err"} .= "\n" . $@ . "\n\n";
								}
								else
								{
									if ( length($dif) > 1 && $dif ne "---" )
									{
										#Print only once.
										if ( $count == 0 )
										{
											$output{"${dc}-out"} = "#" x 100 ."\n" ."Differences In Configurations at ${dc}: \n" . "#" x 100 ."\n";
										}
										$count++;
										
										@disp = split("\n", $dif);
										$output{"${dc}-out"}.= "\n" . ("*" x 75 ) .  "\n";
                                                				$output{"${dc}-out"} .= "New : ${url}${dc}/" . $locDirs{'cur'} . "/" .  basename($devFiles{"${dc}-${cFile}-file"}) . "\t";
										$output{"${dc}-out"} .= "Old : " . "${url}${dc}/" .$locDirs{'arch'}. "/" . basename($oFile) . "\n" . ("~" x 75 ) .  "\n";
										$nodifference=0;
										foreach $dFile ( @disp )
										{
											$output{"${dc}-out"} .= $dFile . "\n";
										}
									}
									else
									{
										#$output{"${dc}-out"} .= "\n-No Difference-" . "\n";
										$nodifference = 1;		
									}
								}
								
								if( $nodifference == 0 )
								{
									$output{"${dc}-out"}.= "\n" . ("~" x 75 ) .  "\n";
								}

							}
						}
						if ( $nodifference == 0 )
						{
							$output{"${dc}-out"}.= "\n" . ("*" x 75 ) .  "\n\n";
						}		
					}				
				}
			}
		}
		else
		{
			$output{"${dc}-err"} = "#" x 100 ."\n" ."Generating Differences In Configurations at ${dc}: \n" . "#" x 100 ."\n";
		 	$output{"${dc}-err"} = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
			$output{"${dc}-err"} .= "\n\n Skipping... No Previous Configs!!! \n\n";
			#$output{"${dc}-out"} .= "\n Skipping... No Previous Configs!!!\n\n";
		}
			
	
		my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n";
		if ($output{"${dc}-err"} =~  m/^(${chkErr})$/ )
		{	
			$output{"${dc}-err"} .= "\nNo Errors Detected\n\n";
		} 
		LogReport("${logFileName}${curLog}.log", $output{"${dc}-out"} . $output{"${dc}-err"} );	
	}
	
	return %output;
	
}




		
		
	

sub emailReport
{
	my $subject	= $_[0];
	my $message	= $_[1];
	my $mailfrom	= $_[2] . '@' . $sysName . ".icontrol.com";
	my $mailto	= $emailAddr;
	

	#/usr/sbin/sendmail
	my $mailcmd	= "/usr/sbin/sendmail -t";

	my $emailTXT = "To: ${mailto}\nFrom: ${mailfrom}\nSubject: ${subject}\n\n${message}";

	open (MAIL, " | $mailcmd") or die "Can't open mail command\n";
	print MAIL "$emailTXT\n";
	close (MAIL);
}
sub Main
{
	my $output;

	my %Dirs = verifyDirs(); # Verify Directory Structure First
	my %devList = grabDeviceList(); # Get the list of devices
	my %Prev = getPrevious(); # Check for Previous Files
	my %binResults = initConfigRun(); # Transfer configs to the admin servers
	my %devConfigs = grabDeviceConfigs(); # Grab the config files from the admin servers
	my %sConfigs = saveConfigs(); # Save configs to file
        my %movPrev = movePrevious(); #Move the previous files to archive
	my %diffReport = genDiffReport(); #Check for differences in configurations
	
	my $diffEmail; #Difference

	my $chkErr = "-" x 100 ."\n" ."Errors : \n" . "-" x 100 ."\n" . "\nNo Errors Detected\n\n";

	foreach $dc (keys (%admServer) )
	{
		$output="";
		if ( !($Dirs{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.=$Dirs{"${dc}-out"};
			$output.=$Dirs{"${dc}-err"};
		}
	
		if ( !($Prev{"${dc}-err"} =~  m/^(${chkErr})$/) )	
		{
			$output.=$Prev{"${dc}-out"};
			$output.=$Prev{"${dc}-err"};
		}

		
		if ( !($movPrev{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.=$movPrev{"${dc}-out"};
			$output.=$movPrev{"${dc}-err"};
		}

			
		if ( !($devList{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.= $devList{"${dc}-out"};
			$output.=$devList{"${dc}-err"};
		}

		if ( !($binResults{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.=$binResults{"${dc}-out"};
			$output.=$binResults{"${dc}-err"};
		}

		if ( !($devConfigs{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.=$devConfigs{"${dc}-out"};
			$output.=$devConfigs{"${dc}-err"};
		}

		if ( !($sConfigs{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.=$sConfigs{"${dc}-out"};
			$output.=$sConfigs{"${dc}-err"};
		}

		$diffEmail=$diffReport{"${dc}-out"};

		if ( !($diffReport{"${dc}-err"} =~  m/^(${chkErr})$/) )
		{
			$output.=$diffReport{"${dc}-err"};
		}	
		
		if ($diffEmail)
		{
			emailReport("${dc} Data Center Network Device Differences: ${curDate}",$diffEmail,$dc);
		}
		
		if ($output)
		{
			emailReport("${dc} Data Center Network Device Configuration Backup Errors: ${curDate}",  $output, $dc);
		}
	}

	

	
}


Main();






