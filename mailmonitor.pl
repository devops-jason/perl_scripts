#!/usr/bin/perl 
# added mailq checker           - david devault 7/5/2006
# added way to set conf params externally - jmiller 11/11/2010
# added better way to check for mailq numbers on sendmail servers

use strict;
use warnings;
use Data::Dumper;

my $monitorConf = "/usr/local/etc/mailmonitor.conf";
my $monitorLocal = "/usr/local/etc/mailmonitor.local";

if ( -r $monitorConf )
{
	open FILE, "<${monitorConf}";
	my @data = <FILE>;

	my $confData = join ( "\n", @data );

	eval ( $confData );
	
	if ( $@ )
	{
		print Dumper ( $@ );
	}

}


if ( -r $monitorLocal )
{
        open FILE, "<${monitorLocal}";
        my @data = <FILE>;

        my $confData = join ( "\n", @data );

        eval ( $confData );

        if ( $@ )
        {
                print Dumper ( $@ );
        }

}

#########
# CONFIGS
#########
my $system              = $ENV{'HOSTNAME'};
if ( ! $system )
{
	$system = `uname -n`;

	if ( ! $system =~ /^(.*)\.(.*)\.com$/ )
	{
		$system = $system . ".icontrol.com";
	}
}
else
{
	if ( ! $system =~ /^(.*)\.(.*)\.com$/ )
        {
                $system = $system . ".icontrol.com";
        }
}

my $localtime           = localtime;

my $MAILSERVER		= $ENV{"MAILSERVER"};

if ( ! $MAILSERVER )
{
	$MAILSERVER = "sendmail";
}
elsif ( ! ($MAILSERVER =~ m/sendmail/i ) || ! ( $MAILSERVER =~ m/postfix/i ))
{
	$MAILSERVER = "sendmail";
}
else
{
	$MAILSERVER =~ tr/[A-Z]/[a-z]/;
}


my $red_email		= $ENV{"EMAIL_RED"};

if ( ! $red_email )
{
	$red_email = '4083961948@vtext.com,4086282573@vtext.com';
}

my $red_queue		= $ENV{"RED_QUEUE"};

if ( ! $red_queue )
{
	$red_queue = 30;
}

my $yellow_email 	= $ENV{"EMAIL_YELLOW"};

if ( ! $yellow_email )
{
        $yellow_email = 'sysadmin@icontrol.com';
}

my $yellow_queue           = $ENV{"YELLOW_QUEUE"};

if ( ! $yellow_queue )
{
        $yellow_queue = 30;
}

my $yellow_queueout           = $ENV{"YELLOW_QUEUEOUT"};

if ( ! $yellow_queueout )
{
        $yellow_queueout = 1;
}

my $red_queueout           = $ENV{"RED_QUEUEOUT"};

if ( ! $red_queueout )
{
        $red_queueout = 3;
}

#########################################################

################################
#
## MAILQ TESTS
#
################################

my ($output, $total_mails, $que_out, $client_mqueue, $mqueue);

if ($MAILSERVER eq "sendmail") {

	## sendmail ##
	$output = `mailq | grep "Total requests:"`;

	if ( $output =~ m/Total requests: (\d+)/ )
	{
		$total_mails = $1;
	}
	else
	{
		$total_mails = "unknown";
	}
	
	if ( `ls -1 /var/spool/mqueue/ | wc -l` =~ m/(\d+)/ )
	{
		$mqueue= ( $1 / 2 );
	}
	else
	{
		$mqueue="unknown";
	}
	
	if ( `ls -1 /var/spool/clientmqueue | wc -l` =~ m/(\d+)/ )
	{
		$client_mqueue=( $1 / 2 );
	}
	else
	{	
		$client_mqueue="unknown";
	}

	$output = `mailq -Ac | grep "Total requests:"`;
	
	if ( $output =~ m/Total requests: (\d+)/)
	{
		$total_mails+=$1;
	}
	
	if ( ($mqueue + $client_mqueue) - $total_mails != 0 )
	{
		$que_out = ($mqueue + $client_mqueue) - $total_mails;
	}
	else
	{
		$que_out = 0;
	}	
	

} elsif ($MAILSERVER eq "postfix") {

        ## postfix ##
        $output = `mailq | tail -1`;
        if ($output =~ /empty/i ){
                $total_mails = "0";
        } else {
                (undef, undef, undef, undef, $total_mails, undef) = split(" ", $output);
        }

}

if ( $total_mails =~ /^unknown$/ || $que_out =~ /^unknown$/ )
{
	if ( $total_mails =~ /^unknown$/  )
	{
		print "Unable to determine total mail\n";
	}
	
	if ( $que_out =~ /^unknown$/  )
	{
		print "Unable to determine how many are no longer in the que\n";
	}

	exit 1;
}

if ((( $total_mails > 0 ) && ( $total_mails >= $yellow_queue ) && ( $total_mails < $red_queue )) || (( $que_out > 0 ) && ( $que_out >= $yellow_queueout ) && ( $que_out < $red_queueout )))
{
	my $msg;

	if ( $que_out > 0 )
	{
		if ( $que_out == 1 && $yellow_queueout == 1 )
		{
			$msg = "WARNING: $que_out message is no longer in the mail queue at $localtime\n";
		}
		else
		{
			$msg = "WARNING: $que_out messages are no longer in the mail queue at $localtime\n";
		}
	}
	if ( $total_mails > 0 )
	{
		if ( $total_mails == 1 && $yellow_queue == 1 )
		{
			$msg .= "WARNING: $total_mails message in the mail queue at $localtime\n";
		}
		else
		{
			$msg .= "WARNING: $total_mails messages in the mail queue at $localtime\n";
		}
	}
        my $email       = "$yellow_email";
        my $subject     = "$system Email Queue WARNING";
        SendEmail("$email","$subject","$msg");
} elsif ( $total_mails >= $red_queue || $que_out >= $red_queueout ) {
	
	my $msg;
	if  ( $que_out >= $red_queueout && $red_queueout >= 2 )
	{
		$msg = "ALERT: $que_out messsages are no longer in the mail queue at $localtime\n";
	}

	if ( $total_mails >= $red_queue && $red_queue >= 2 )
	{
		$msg .= "ALERT: $total_mails messages in the mail queue at $localtime\n";
	}

        my $email       = "$yellow_email,$red_email";
        my $subject     = "$system Email Queue ALERT";
        SendEmail("$email","$subject","$msg");
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
my $mail_from   = 'mailmon@' . $system;

#/usr/sbin/sendmail
my $mailcmd     = "/usr/sbin/sendmail -t -f $mail_from";
my $mess        .= "Subject: $subject\n";
$mess           .= "To:  $mail_to\n";
$mess           .= "From:  $mail_from\n";

open(MAIL,"| $mailcmd") || die "Can't open mail command\n";
print MAIL "$mess\n";
print MAIL "$message\n";
close(MAIL);
}

