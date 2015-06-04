#!perl
# Copyright 2014 Ruslan Shvedov

#
use 5.10;
use warnings;
use strict;

use Test::More;
use Test::Differences 0.61;

use MarpaX::Languages::Lua::AST;

# fact is lua's hello world -- test formatter by comparing it with
# this nonexecutable snippet

my @tests = (

[
# source code
q{
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n-1)
  end
end

function tcheck (t1, t2)
  table.remove(t1, 1)  -- remove code
  assert(table.getn(t1) == table.getn(t2))
  for i=1,table.getn(t1) do assert(t1[i] == t2[i]) end
end

print("enter a number:")
a = io.read("*number")        -- read a number
print(fact(a))},
# formatted code
q{
function fact (n)
  if n == 0 then
    return 1
  else
    return n * fact(n - 1)
  end
end

function tcheck (t1, t2)
  table.remove(t1, 1)  -- remove code
  assert(table.getn(t1) == table.getn(t2))
  for i = 1, table.getn(t1) do
    assert(t1[i] == t2[i])
  end
end

print("enter a number:")
a = io.read("*number")  -- read a number
print(fact(a))}
],

# source code
[ q{
a = f
(g).x(a)

f = [[
return function ( a , b , c , d , e )
  local y = 1
  local x = a >= b or c or ( d and e ) or nil
  return x
end , { a = 1 , b = 2 >= 1 , } or { 1 };
]]
f = string.gsub(f, "%s+", "\n");  -- force a SETLINE between opcodes
f,a = loadstring(f)();
},
# expected formatted code
q{
a = f(g).x(a)
f = [[
return function ( a, b, c, d, e )
  local y = 1
  local x = a >= b or c or ( d and e ) or nil
  return x
end, { a = 1, b = 2 >= 1, } or { 1 };
]]
f = string.gsub(f, "%s+", "\n");  -- force a SETLINE between opcodes
f, a = loadstring(f)();
} ],

# [ q{}, ]
# [ q{}, q{} ]
);

my $p = MarpaX::Languages::Lua::AST->new;

for my $test (@tests){
    my ($lua_src, $expected_fmt) = @$test;

    # trim spaces
    $expected_fmt =~ s/^\s+//ms;
    chomp $expected_fmt;

    # parse/reparse with diagnostics on error
    my $ast = $p->parse( $lua_src );
    unless (defined $ast){
        $p->parse( $lua_src, { trace_terminals => 1 } );
        fail "Can't parse:\n$lua_src";
    }

    # an ast dump is needed first at times
#    say $p->serialize( $ast );

    my $fmt = $p->fmt( $ast, { indent => '  ' } );
#    say $fmt;

    eq_or_diff $fmt, $expected_fmt, 'lua code formatting';

}

done_testing();

