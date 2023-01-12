#!/usr/bin/perl -w
use strict;
#
# backupfiles.pl 10/31/2007 - David DeVault
#
# Used to backup files that exist on the filesystem into 
# tar format that contains the current day in filename
#
# Note:		Assumes 7 day roration period (don't want to keep more than 7 days)
#		Long term "central" storage policies differ per host/media stored
#
# Required Files:
#
#	iCbackup.pl		: Backup Script
#	iCbackup.filelist	: Filelist
#	dateFilter.pl		: Date/Time Padding Filter for STDOUT
#
#####################
#
##Backup Files - crontab entry
#
#0 2 * * * /usr/local/sbin/iCbackup.pl | /usr/local/sbin/dateFilter.pl >> /var/log/iCbackup.log
#
#################################################
#
# 12/08/2008 - David DeVault
#	- redirected STDERR to STDOUT
#	- enhanced file testing with wildcard hosts
#	- added file test within perl instead of using ls 
#	- split filelist into separate filelist infile
#	- added duration, filesize and cleaned output
#
#################################################

 BEGIN {                                   
      $| = 1;
      open STDERR, ">&STDOUT";
  }


chomp(my $hostname = `uname -n`);
my $start_time	= time();
my @backupfiles	= ();
my @weekDays    = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
my $day         = (localtime)[6];
my $dir         = "/data/backupfiles/current";
my $filelist	= "/usr/local/sbin/iCbackup.filelist";
my $excludelist = "/usr/local/sbin/iCbackup.exclude";
my $optfilelist = "/usr/local/sbin/iCbackup.local";
my $dest_name	= "${hostname}_backup_${weekDays[${day}]}.tgz";
my $filename    = "${dir}/${dest_name}";

print("================ STARTING ================\n");

open(FILE, "${filelist}") or die("Unable to open file: $!");
my @entries = <FILE>;
close(FILE);

if ( -f "${optfilelist}" )
{	
	open(FILE, "${optfilelist}") or die("Unable to open file: $!");
	my @optentries = <FILE>;
	close(FILE);
	push (@entries,@optentries);
}

for my ${entry} ( @entries ) {
chomp ${entry};
next if ${entry} =~ /^#/;

if ((${entry} =~ /\*/) || (${entry} eq "/data/build/work" )) {
        if (${entry} eq "/data/build/work") {
	#CruiseControl Working Files Condition
		next if ( ! -f ${entry} );

		opendir( DIR, ${entry} ) or die "Can't open ${entry}";
		my @{workfiles} = readdir(DIR);
		closedir DIR; 

		for my ${workfile} ( @{workfiles} ) {

			next if ${workfile} eq "." || ${workfile} eq ".."; 
			my ${workfullpath} = "${entry}/${workfile}";
			chomp ${workfullpath};

                        if ( -f ${workfullpath} ) {
                                push (@{backupfiles}, "${workfullpath}"); 
                        }
                }
        } else {
	#WildCard Condition
		my @{wildcardfiles} = <${entry}>;

		for my ${wildcardfile} ( @{wildcardfiles} ) {

			next if ${wildcardfile} eq "." || ${wildcardfile} eq ".."; 
			chomp ${wildcardfile};
			
                        if ( -f ${wildcardfile} ) {
                                push (@{backupfiles}, "${wildcardfile}"); 
                        }
                }
        }

} else {

        if (( -f ${entry} ) || ( -d ${entry} )) {
               push (@{backupfiles}, "${entry}"); 
        } 

}

} #end for entry

if (!-d ${dir}) {
`mkdir ${dir} -p`
}

if ( -f $excludelist && -r $excludelist && !(-z $excludelist) )
{

        print "Filelist: @{backupfiles}\n";
        print "Exclude: " . `cat $excludelist | tr '\n' ' '` . "\n";
        system("tar --absolute-names -czf '$filename' @{backupfiles} --exclude-from $excludelist; cd ${dir}; md5sum `basename ${filename}` > ${filename}.md5");
}
else
{
        print "Filelist: @{backupfiles}\n";
        system("tar --absolute-names -czf '$filename' @{backupfiles}; cd ${dir}; md5sum `basename ${filename}` > ${filename}.md5");
}
my $size = sprintf("%.2f", ( (stat("${filename}"))[7] / 1024 / 1024 ) );
my $total_time  = ( time() - ${start_time} );
print "Duration (seconds): ${total_time} Filename: ${dest_name} Size: $size MB\n";
print("================ COMPLETE ================\n");

