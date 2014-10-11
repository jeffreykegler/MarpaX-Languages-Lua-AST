#!perl
# Copyright 2014 Ruslan Shvedov

# take a source code of a lua function and test its execution results
# returned via Inline::Lua for the original source code and
# for the source code parsed to AST and serialized to a token stream
# todo: add functions from 2.8 – Metatables
#       starting at "That is, the access to a metamethod does not invoke other metamethods"

=pod

After the collection, Lua does the equivalent of the following function for each userdata in that list:

     function gc_event (udata)
       local h = metatable(udata).__gc
       if h then
         h(udata)
       end
     end
=cut

use 5.010;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

my $lua_fact;
BEGIN {
    $lua_fact = <<END;
-- defines a factorial function
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end
END
};

# lua source from a scalar initialized at compile time
use Inline Lua => $lua_fact;
my $n = 10;
my $expected_fact = fact($n);

sub lua_fact_tokens {
    my $p = MarpaX::Languages::Lua::AST->new;
    $p->tokens($p->parse($lua_fact))
}

# lua source from a ref to code returning ast of lua source
use Inline Lua => &lua_fact_tokens;
my $got_fact = fact($n);

is $got_fact, $expected_fact, "$n! from lua source and its ast serialized to tokens";

done_testing();

