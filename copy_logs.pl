#!/usr/bin/perl

#use warnings;

$logsdir = "/data/logs/all";
#$logsdir = "/root/gilbert/logs";
$tomcatdir = "/data/ic/tomcat/logs";
#$tomcatdir = "/root/gilbert/tomcat/logs";
$today = `date +%Y%m%d`;
chomp($today);
$tomcat_date = `date +%Y-%m-%d`;
chomp($tomcat_date);

################################################################
# Getting Apache Access Logs
################################################################

$accesslog = "${logsdir}/*access*";
if ( $accesslog ne "" )
{ 
	@myalogs = (${accesslog});
	@list = <@{myalogs}>;
	chomp(@list);
	foreach $list(@list)
	{
		if ( $list =~ m/(.*)(access_log)\.(\d+)/ )
		{
			if ( $list !~ m/${today}/ )
			{
			$axesdirname = "accesslogs.${today}";
			mkdir "$axesdirname";
			system("cp -p ${list} ${axesdirname}");
			} 
				
		}
	}
} else {
		$axesdirname = undef;
		print "*" x 35 , "\n";
		print "HTTP REQUEST LOGS\n";
		print "*" x 35 , "\n";
		print "There are no Apache \*access\* logs\n\n";
	     }

	if ( -d $axesdirname ) 
	{
	system("tar -zpcvf /data/logs/all/$axesdirname.tgz $axesdirname 1> /dev/null");
	system("rm -rf $axesdirname");
	} else 
		{
		print "\n";
		print "*" x 35 , "\n";
		print "Direcotry doesn't exist.\n";
		print "*" x 35 , "\n\n";
		}


################################################################
# Getting Apache Request Logs
################################################################

$requestlog = "${logsdir}/*request*";
if ( ! $requestlogs )
{ 
@rqlogs = <${requestlog}>;
chomp(@rqlogs);

foreach $httprequestlogs(@rqlogs)
{
        if ( $httprequestlogs =~ m/(.*)(request_log)\.(\d+)/ )
        {
                 if ( $httprequestlogs !~ m/${today}/ )
                 {
#                print "$httprequestlogs\n";
 		 $httpdirname = "httprequestlogs.${today}";
                 mkdir "$httpdirname";
                 system("cp -p ${httprequestlogs} ${httpdirname}");
                 }
        }
}
	if ( -d $httpdirname ) 
	{
 	system("tar -zpcvf /data/logs/all/$httpdirname.tgz $httpdirname 1> /dev/null");
 	system("rm -rf $httpdirname");
	} else 
		{
		print "\n";
		print "*" x 35 , "\n";
		print "There are no Apache \*request\*.\n";
		print "*" x 35 , "\n\n";
		}

	} else 
		{
		$requestlog = undef;
		print "*" x 35 , "\n";
		print "HTTP REQUEST LOGS\n";
		print "*" x 35 , "\n";
		print "There are no \*request\* logs\n\n";
}

################################################################
# Getting Tomcat Logs
################################################################

$tomcatlog = "${tomcatdir}/*access*";
if ( $tomcatlog ne "" )
{ 
@tclogs = <${tomcatlog}>;
chomp(@tclogs);
foreach $tomcatlogs(@tclogs)
{
	if ( $tomcatlogs =~ m/(.*)(access_log)\.(\d+)/ )
        {
		if ( $tomcatlogs !~ m/${tomcat_date}/ )
		{
#		print "$tomcatlogs\n";
		$tcdirname = "tomcatlogs.${today}";
                mkdir "$tcdirname";
                system("cp -p ${tomcatlogs} ${tcdirname}");
		}
	}
}

	if ( -d $tcdirname ) 
	{
	system("tar -zpcvf /data/logs/all/$tcdirname.tgz $tcdirname 1> /dev/null");
	system("rm -rf $tcdirname");
	} else 
		{
		print "\n";
		print "*" x 35 , "\n";
		print "There are no files with tomcat \*access\*.\n";
		print "*" x 35 , "\n\n";
		}

	} else 
		{
		$tomcatlog = undef;
		print "*" x 35 , "\n";
		print "TOMCAT ACCESS LOGS\n";
		print "*" x 35 , "\n";
		print "There are no tomcat \*access\* logs\n\n";
}
