#!/usr/bin/perl 
#########
# CONFIGS
#########

my @FS = ("/","/boot","/data","/usr","/var");

my $system              = `uname -n`;
my $localtime           = localtime;
my $sectime           = time;
my $MAILSERVER 		= "sendmail";
## $MAILSERVER is "postfix" or "sendmail" for now

#RED - PAGE
my $red_email           = '4086282573@vtext.com';
my $disk_red_limit	= 90;    # More than 90% used, page
my $swap_red_limit 	= 5;     # percentage swap avail 
my $mem_red_limit 	= 5;     # percentage mem avail 
my $load_red_limit 	= 4;     # load average limit
my $red_queue           = 50;    # mail queue red limit

#YELLOW - EMAIL
my $yellow_email        = 'sysadmin@icontrol.com';
my $disk_yellow_limit	= 80;    # More than 80% used, email
my $swap_yellow_limit 	= 10;    # percentage swap avail 
my $mem_yellow_limit 	= 10;    # percentage mem avail 
my $load_yellow_limit 	= 2;     # load average limit
my $yellow_queue        = 30;    # mail queue yellow limit
#########################################################
use strict;
use warnings;
use GTop ();

my $gtop = GTop->new;

################################
#
## DISK TESTS
#
################################

my %DISK_ERRORS = ();

# Loop through each directory in the list.
foreach my $dir (@FS) {

	my $fsusage = $gtop->fsusage($dir);
	my $blocks = $fsusage->blocks;
	my $bfree = $fsusage->bfree;

	$blocks = $blocks / 2;
	$bfree = $bfree / 2;

	my $disk_used = $blocks - $bfree;
	my $per_used = ($disk_used / $blocks) * 100;

	if ($per_used > $disk_red_limit) {
		my $msg = sprintf( "ALERT: Usage of $dir ".  "is %0.2f%% at $localtime", $per_used);
		unless ($DISK_ERRORS{$dir}) {
			# if we get here, we have not seen the fs before
			$DISK_ERRORS{$dir} = "$msg";
		}

	} elsif ($per_used > $disk_yellow_limit) {
		my $msg = sprintf( "WARNING: Usage of $dir ".  "is %0.2f%% at $localtime", $per_used);
		unless ($DISK_ERRORS{$dir}) {
			# if we get here, we have not seen the fs before
			$DISK_ERRORS{$dir} = "$msg";
		}
	}

}

foreach my $fs (sort(keys(%DISK_ERRORS))) {
	my $disk_msg = $DISK_ERRORS{$fs};

	if ($disk_msg =~ /alert/i) {

		my $email	= "$yellow_email,$red_email";
		my $subject	= "$system DISK $fs ALERT";
		SendEmail("$email","$subject","$disk_msg");

	} elsif ($disk_msg =~ /warning/i) {

		my $email	= "$yellow_email";
		my $subject	= "$system DISK $fs WARNING";
		SendEmail("$email","$subject","$disk_msg");

	}
}

################################
#
## MEMORY TESTS
#
################################

my $mem		= $gtop->mem;
my $memtotal	= $mem->total;
my $memfree	= $mem->free;
my $membuffer	= $mem->buffer;
my $memcached	= $mem->cached;

## Available is (free + cache + buffer)
## Used is (used - cache - buffer)

my $real_mem_free	= ($memfree + $memcached) + $membuffer;
$real_mem_free		= ($real_mem_free / 1024) / 1024;

$memtotal = ($memtotal / 1024) / 1024;
$memtotal = sprintf("%.0f", $memtotal);

my $per_mem_free	= ($real_mem_free / $memtotal) * 100;
$per_mem_free		= sprintf("%0.2f", $per_mem_free);

if ($per_mem_free < $mem_red_limit) {

	my $email	= "$yellow_email,$red_email";
	my $subject	= "$system MEMORY ALERT";
	my $mem_msg	= sprintf( "ALERT: Free Memory ".  "is %0.2f%% at $localtime", $per_mem_free);
	SendEmail("$email","$subject","$mem_msg");

} elsif ($per_mem_free < $mem_yellow_limit) {

	my $email	= "$yellow_email";
	my $subject	= "$system MEMORY WARNING";
	my $mem_msg	= sprintf( "WARNING: Free Memory ".  "is %0.2f%% at $localtime", $per_mem_free);
	SendEmail("$email","$subject","$mem_msg");

}


################################
#
## SWAP TESTS
#
################################

my $swap	= $gtop->swap;
my $swaptotal	= $swap->total;
my $swapused	= $swap->used;
my $swapfree	= $swap->free;

$swaptotal	= ($swaptotal / 1024) / 1024;
$swapused	= ($swapused / 1024) / 1024;
$swapfree	= ($swapfree / 1024) / 1024;

my $swapavail		= $swaptotal - $swapused;
my $per_swap_free	= ($swapfree / $swaptotal) * 100;

$per_swap_free		= sprintf("%0.2f", $per_swap_free);

if ($per_swap_free < $swap_red_limit) {

	my $email	= "$yellow_email,$red_email";
	my $subject	= "$system SWAP ALERT";
	my $swap_msg	= sprintf( "ALERT: Free SWAP ".  "is %0.2f%% at $localtime", $per_swap_free);
	SendEmail("$email","$subject","$swap_msg");

} elsif ($per_swap_free < $swap_yellow_limit) {

	my $email	= "$yellow_email";
	my $subject	= "$system SWAP WARNING";
	my $swap_msg	= sprintf( "WARNING: Free SWAP ".  "is %0.2f%% at $localtime", $per_swap_free);
	SendEmail("$email","$subject","$swap_msg");

}

################################
#
## LOAD AVERAGE TESTS
#
################################

open(LOAD,"/proc/loadavg") || die "couldn't open /proc/loadavg: $!\n";
my @loadavg=split(/ /,<LOAD>);
close(LOAD);

if ($loadavg[0] >= $load_red_limit) {

	my $email	= "$yellow_email,$red_email";
	my $subject	= "$system Load Average ALERT";
	my $total_conn  = `netstat -na | egrep '^tcp|^udp' |wc -l`;
	my $total_proc  = `ps -ef |wc -l`;
	my $total_free  = `free -m|head -2`;
	my $total_uptime  = `uptime`;
        my $load_msg    = "\nALERT: Load Average is $loadavg[0] at $localtime\n\nConnections: $total_conn\nProcesses: $total_proc\nMemory: $total_free\nUptime: $total_uptime\n";
	SendEmail("$email","$subject","$load_msg");
        `ps -ef > /data/high_load_files/ps.$sectime`;
        `netstat -na > /data/high_load_files/netstat.$sectime`;
        `ps -eo pid,ppid,pmem,pcpu,rss,vsz,user,args --sort=-rss --forest|head -15 > /data/high_load_files/high_mem.$sectime`;
        `ps -eo pid,ppid,pmem,pcpu,rss,vsz,user,args --sort=-pcpu --forest|head -10 > /data/high_load_files/high_cpu.$sectime`;

} elsif ($loadavg[0] >= $load_yellow_limit) {

	my $email	= "$yellow_email";
	my $subject	= "$system Load Average WARNING";
	my $load_msg	= "\nWARNING:  Load Average is $loadavg[0] at $localtime\n";
	SendEmail("$email","$subject","$load_msg");

}



################################
#
## MAILQ TESTS
#
################################

my ($output, $complete_output, $total_mails, @que_out);

if ($MAILSERVER eq "sendmail") {

	## sendmail ##
	$complete_output = `mailq`;
	$output = `mailq | head -1`;
	if ($output =~ /empty/i ){
		$total_mails = "0";
	} else {
		@que_out = `ls -1 /var/spool/mqueue/df*`;
		$total_mails = $#que_out;
	}

} elsif ($MAILSERVER eq "postfix") {

	## postfix ##
	$complete_output = `mailq`;
	$output = `mailq | tail -1`;
	if ($output =~ /empty/i ){
		$total_mails = "0";
	} else {
		(undef, undef, undef, undef, $total_mails, undef) = split(" ", $output);
	}

}

if (( $total_mails > $yellow_queue ) && ( $total_mails < $red_queue )) { 

	my $email	= "$yellow_email";
	my $subject	= "$system Email Queue WARNING";
	my $mque_msg	= "\nWARNING:  $total_mails messages in Mail Queue at $localtime\n\n\n$complete_output";
	SendEmail("$email","$subject","$mque_msg");

} elsif ( $total_mails > $red_queue ) {

	my $email	= "$yellow_email,$red_email";
	my $subject	= "$system Email Queue ALERT";
	my $mque_msg	= "\nALERT:  $total_mails messages in Mail Queue at $localtime\n\n\n$complete_output";
	SendEmail("$email","$subject","$mque_msg");
}

################################
#
## Send Email SUB
#
################################

sub SendEmail {
my $email       = $_[0];
my $subject     = $_[1];
my $message     = $_[2];
my $mail_to     = "$email";
my $mail_from   = 'sysmon@' . $system;

#/usr/sbin/sendmail
my $mailcmd	= "/usr/sbin/sendmail -t -f $mail_from";
my $mess	.= "Subject: $subject\n";
$mess		.= "To:  $mail_to\n";
$mess		.= "From:  $mail_from\n";

open(MAIL,"| $mailcmd") || die "Can't open mail command\n";
print MAIL "$mess\n";
print MAIL "$message\n";
close(MAIL);
}
