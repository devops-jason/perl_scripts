#!/usr/bin/perl

use IO::Socket::INET;
$HOSTNAME = $ARGV[0];
$PORTNO = 4447;
$TIMEOUT = 5;

$HOSTNAME =~ s/::ffff://;

$socket = new IO::Socket::INET->new(
  PeerAddr => $HOSTNAME,
  PeerPort => $PORTNO,
  Proto    => 'udp'
  );
die "" unless $socket;
$request = pack("H* a12", "5CBCD87FF68849F3", "000000000000");
$socket->send($request);

eval {
    alarm $TIMEOUT;
    $socket->recv($response, 1000);
    alarm 0;
};

$result = unpack("H*", $response);
$result = substr($result,0,32);
$match = ($result =~ /^5cbcd87ff68849f33030303030303030$/);
if ($match) {
  print "UP\n";
  }
