#!/usr/bin/perl 

@servers=('logwatch1','logwatch2','logwatch3');

$logwatchfile="/data/logwatch/logwatch";
$begin=0;

foreach (@servers)
{
	$begin=0;
	$end = 0;	
	$found = 0;
	@results = `ssh $_ "cat $logwatchfile"`;
	$arrref=\@results;
	$logdata{$_}=$arrref;
	#print @{$logdata{$_}};
	
	while($done == 0)
	{
		while( $begin == 0 || $end == 0 && $found != 1)
		{
			if ( $i <= $#{$logdata{$_}} )
			{

				if ($logdata{$_}[$i] =~ /Begin ---/ )
				{
					$begin=$i;
				}
				if ($logdata{$_}[$i] =~ /End ---/ )
                                {
                                        $end=$i;
                                        $found=1;
                                }
				else
				{
				
					if( $i > $begin && $end==0)
                        	        {
                               			print $logdata{$_}[$i];
                                	}
				}

				 $i += 1;
			}
			else
			{
				$done = 1;
				$found = 1;
			}

		
			print $i ."\n";	
		}
	$found=0;
	}
}

