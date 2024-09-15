#!/usr/bin/perl
use strict;
use warnings;

use Digest::CRC;

my $ctx = Digest::CRC->new(type => "crc32", init => 0x0, xorout => 0x0, refout => 1, refin => 1, poly => 0x4C11DB7);
while (<>) {
    $ctx->add($_);
}

print pack V=>$ctx->digest
