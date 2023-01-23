#!/usr/bin/perl 
#
#
############################
#
# get_configs.pl: Start tftp and login to all switches and firewalls to send tftp configs to tftp server
#
############################
  use Net::Telnet::Cisco;
  my $password     = "";
  my $enablepass   = "";
  my $device       = "10.60.10.2";
  my $backup_host  = "10.60.10.90";
  my $Output;

  my $Session = Net::Telnet::Cisco->new(Host => '10.60.10.2');

  $Output = $Session->login(Password => $password);

  # Enable mode
  if ($Session->enable("$enablepass") ) {
      @Output = $Session->cmd("copy system:/running-config tftp://$backup_host/$device-confg\n\n\n");
      print "Write Net:\n\n @Output\n";
  } else {
      warn "Can't enable: " . $Session->errmsg;
  }

  $Session->close;

#  if ($type eq "router") {
#      if ($ios_version >= 12) {
#          @out = $session->cmd("copy system:/running-config "
#                        . "tftp://$backup_host/$device-confg\n\n\n");
#      } elsif ($ios_version >= 11) {
#          @out = $session->cmd("copy running-config tftp\n$backup_host\n"
#                        . "$device-confg\n");
#      } elsif ($ios_version >= 10) {
#          @out = $session->cmd("write net\n$backup_host\n$device-confg\n\n");
#      }
#  } elsif ($type eq "switch") {
#      @out = $session->cmd("copy system:/running-config "
#                    . "tftp://$backup_host/$device-confg\n\n\n");
#  }
