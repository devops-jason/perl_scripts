#!/usr/bin/perl

use XML::Simple;
use strict;
use Data::Dumper;

my $xml = new XML::Simple;
my $indata = "";


while (<STDIN>)
{
        $indata .= $_;
}

my $xmldata = $xml->XMLin($indata);
print dumper ( $xmldata );

