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
  my $device       = "10.100.130.1";
  my $backup_host  = "10.60.10.90";
  my $Output;

  my $Session = Net::Telnet::Cisco->new(Host => $device, Input_log => "input.log");

$Session->always_waitfor_prompt;

# Wait for the password prompt and enter the password
@Output = $Session->waitfor('/Password: /');
@Output = $Session->print($password);
@Output = $Session->waitfor('/fw1>/');
@Output = $Session->print("enable");
@Output = $Session->waitfor('/Password: /');
@Output = $Session->print("$enablepass");
@Output = $Session->waitfor('/fw1#/');
@Output = $Session->print("write net $backup_host:/sjc-pix-confg\n\n");
@Output = $Session->waitfor('/fw1#/');
@Output = $Session->close;

#$Session->close;

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
