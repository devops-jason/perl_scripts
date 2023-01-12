#!/usr/bin/perl -w

use warnings;
use Data::Dumper;

my $cvalue;
my $tvalue;
#my @hostfile = /usr/local/sbin/hostlist;

	print "\n";
	print '=' x 60 . "\n";
	$hostname = `uname -n`;
	print "\t\t Host: $hostname";
	print '=' x 60 . "\n";
	print "\n";

sub getcpuinfo
{
	$cpu = `cat /proc/cpuinfo | grep -i "model name" | sort -u | awk -F ":" '{print \$2}' | sed -e 's/^[ \t]*//'`;
	chomp($cpu);
	$cpu =~ s/^(\s)//;
	@cpu = split(/\s{11}/, $cpu);
	$manu = `dmidecode | grep -i manufacture | sort -nu | awk -F ":" '{print \$2}'`;
	chop($manu);
	$pname = `dmidecode | grep -i "product name" | sort -nu | awk -F ":" '{print \$2}'`;
	print '-' x 60 . "\n";
	print "\t\t CPU Information\n";
	print '-' x 60 . "\n";
	print "\n";
	print "Model Type: @cpu\n"; 
	print "Manufacture: $manu\n";
	print "Product Name: $pname\n";
}
getcpuinfo ();

sub getdiskinfo
{
	$disk = "fdisk -l | grep -v grep | grep Disk | awk '{print \$1, \$2, \$3}'";
	print '-' x 60 . "\n";
	print "\t\t Local Hard Drive(s)\n";
	print '-' x 60 . "\n";
	print "\n";
	system("$disk");
	print "\n";
	print '-' x 60 . "\n";
	print "\t\t Memory Infomration\n";
	print '-' x 60 . "\n";
}
getdiskinfo ();

$output=`/usr/sbin/dmidecode`; 
foreach $hash ( split( "\n", $output) )
{
chomp($hash);
$hash =~ s/^\s+//;
$hash =~ s/^\s+$//;
	if ( $hash =~ m/Memory Device/ && (! $open))
	{
		$open = 1;		
	}
	
	if ( $hash =~ m/^Handle 0x0/ && $open )
	{
		$close = 1;
	}	

	if ( $close && $open )
	{
		$close = 0;
		$open = 0;
	}

	if ( $open  && (!$close) )
	{
		if ( $hash =~ m/:/ )
		{
			@data = split(':', $hash);
			if ($data[1])
			{
				if ($data[0])
				{
					%myhash = ( $data[0], $data[1] );
	for $list (keys(%myhash))
	{
		if ($myhash{"Locator"})
		{
		print "Locator:$myhash{$list}\n";
		}
	}

	for $list (keys(%myhash))
	{
		if ($myhash{"Bank Locator"})
		{
		print "Bank Locator:$myhash{$list}\n";
		}
	}

	for $list (keys(%myhash))
	{
		if ($myhash{"Type"})
		{
		print "Type:$myhash{$list}\n";
		}
	}

				#	print Dumper \%myhash;

	for $list (keys(%myhash)) 
	{
		if ($myhash{"Size"})
		{
			foreach $foo ($myhash{$list})
			{	
				if ($foo !~ 'No Module Installed')
				{
       					@values = split(/ /, $foo);
       					$cvalue = $values[1];
					if ($cvalue =~ m/\d+/)
        				{
					#print "$tvalue";
                        		$tvalue += int $cvalue;
        				}
				}
			}
		}
							
	}

	for $list (keys(%myhash))
	{
		if ($myhash{"Size"})
		{
		print "\n";
		print "Size:$myhash{$list}\n";
		}
	}
		
   				}	
			}
		}
   	}
}
print "\n";
print "=" x 60 . "\n"; 
print "Total Memory Size: " . $tvalue . " MB \n";
print "=" x 60 . "\n"; 
print "\n";
