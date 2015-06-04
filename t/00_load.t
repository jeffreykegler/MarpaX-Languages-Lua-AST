#!perl
# Copyright 2014 Ruslan Shvedov

use 5.10;
use warnings;
use strict;

use Test::More;

if (not eval { require MarpaX::Languages::Lua::AST; 1; }) {
    Test::More::diag($@);
    Test::More::BAIL_OUT('Could not load MarpaX::Languages::Lua::AST');
}

use_ok 'MarpaX::Languages::Lua::AST';

done_testing();
