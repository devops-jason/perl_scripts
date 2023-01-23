#!/usr/bin/perl -w
use strict;


#
# backupfiles.pl 10/31/2007 - David DeVault
#
# Used to backup files from the filesystem into a tar file that contains the current date/time stamp
#
#
#################################################

chomp(my $hostname = `uname -n`);
my @weekDays    = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$mon = $abbr[$mon];
$year += 1900;
my $tstamp = "[${mday}/${mon}/${year}:$hour:$min:$sec]"; 
	#[14/Nov/2007:15:39:28]
my $day         = (localtime)[6];
my $dir         = "/data/backupfiles/current";
my $filename    = "${dir}/${hostname}_backup_${weekDays[$day]}";

my @filelist;
my @entries = (
        "/etc/hosts",
        "/etc/passwd",
        "/etc/shadow",
        "/etc/group",
        "/etc/fstab",
        "/etc/nsswitch.conf",
        "/etc/sudoers",
        "/etc/profile",
        "/etc/securetty",
        "/etc/resolv.conf",
        "/etc/sysctl.conf",
        "/etc/syslog.conf",
        "/etc/mail/",
        "/etc/profile",
        "/etc/lilo.conf",
        "/etc/grub.conf",
        "/etc/rc.d/rc.local",
        "/etc/ssh/",
        "/etc/exports",
        "/etc/sysconfig/",
        "/root/.bash_history",
        "/root/.bash_logout",
        "/root/.bash_profile",
        "/root/.bashrc",
        "/root/.cshrc",
        "/root/.ssh",
        "/root/.tcshrc",
        "/root/.viminfo",
        "/var/spool/cron/",
        "/etc/portal/",
        "/etc/keys/",
        "/etc/icsvr/",
        "/etc/init.d/tomcat5",
        "/etc/init.d/httpd-*",
        "/etc/tomcat5/",
        "/data/ic/conf/",
        "/data/site-monitor/",
        "/usr/local/sbin/",
        "/usr/local/etc/",
        "/data/ic/tomcat/conf/",
        "/data/ic/tomcat/webapps/",
        "/data/ic/tomcat/shared/lib/",
        "/data/build/work",
        "/data/www/"
);


        for my $entry ( @entries ) {

if (($entry =~ /\*/) || ($entry eq "/data/build/work" )) {
        if ($entry eq "/data/build/work") {
		next if ( ! -f $entry );

		opendir( DIR, $entry ) or die "Can't open $entry";
		my @workfiles = readdir(DIR);
		closedir DIR; 

		for my $workfile ( @workfiles ) {

			next if $workfile eq "." || $workfile eq ".."; 
			my $workfullpath = "$entry/$workfile";
			chomp $workfullpath;

                        if ( -f ${workfullpath} ) {
                                push (@filelist, "${workfullpath}"); 
                        }
                }
        } else {
		my @wildcardfiles = <${entry}>;

		for my $wildcardfile ( @wildcardfiles ) {

			next if $wildcardfile eq "." || $wildcardfile eq ".."; 
			chomp $wildcardfile;
			
                        if ( -f ${wildcardfile} ) {
                                push (@filelist, "${wildcardfile}"); 
                        }
                }
        }

} else {

        if (( -f $entry ) || ( -d $entry )) {

               push (@filelist, "$entry"); 

        } # end if

        } # end for 

}



#DWD#if (!-d ${dir}) {
#DWD#`mkdir ${dir} -p`
#DWD#}

print "Creating: $filename.tgz\n\nArchive of the following: @filelist\n";
#DWD#system("tar -czf '$filename'.tgz @filelist");
#DWD#print("===============================\n");
