#!/usr/bin/env perl
# Copyright 2014 Ruslan Shvedov

# read LUIF source from the file specified on the command line or standard input
# if no output file is specified transpile it to lua and print the result to the
# file specified on the command line appending '.lua' to its name unless it already
# has such extension or the standard output if no output file is specified

use 5.10;
use warnings;
use strict;

sub usage {
    my $msg = shift || '';
    say STDERR $msg if $msg;
    die "Usage: perl luif2lua.pl [<] input.luif [output[.lua]]";
}

use lib qw{/home/Ruslan/MarpaX-Languages-Lua-AST/lib};

# input
my $luif;
if (defined $ARGV[0]){
    if ( -e $ARGV[0] ){
        open my $in, "<$ARGV[0]" or usage( "Can't open $ARGV[0]: $!." );
        $luif = do { local $/ = undef; <$in> };
        close $in;
    }
    else{
        usage( "Input file $ARGV[0] doesn't exist." );
    }
}
elsif ( not -t STDIN) {
    $luif = do { local $/ = undef; <> };
}

usage( "Input is not specified." ) unless $luif;

# transpile
use MarpaX::Languages::Lua::LUIF;
my $p = MarpaX::Languages::Lua::LUIF->new();
my $lua = $p->transpile( $luif ) or die "Can't parse LUIF source";

# output
my $out_fn;
if (defined $ARGV[1]){
    $out_fn = $ARGV[1];
}
elsif (defined $ARGV[0] and -e $ARGV[0]){
    $out_fn = $ARGV[0];
    $out_fn =~ s/\..*$/.lua/ unless $out_fn =~ /.lua$/ms;
}
else { # write to standard output and exit
    say $lua;
    exit 0;
}

open my $out, ">$out_fn" or usage( "Can't create $out_fn: $!." );
say $out $lua;
close $out;

say STDERR "Transpiled LUIF has been written to $out_fn.";
