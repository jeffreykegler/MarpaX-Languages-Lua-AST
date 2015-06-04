#!perl
# Copyright 2014 Ruslan Shvedov

#
use 5.10;
use warnings;
use strict;

use Test::More;
use Test::Differences 0.61;
use File::Temp qw{ tempfile };

use MarpaX::Languages::Lua::LUIF;

my $p = MarpaX::Languages::Lua::LUIF->new();

# test LUIF to lua transpiling
my @tests = (

[ 'LUIF design note',
# source LUIF
q{
g = grammar ()
  local x = 1
  a ::= b c
  w ::= x y z
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2,n do
    x = x * i
  end
end
},
# expected: transpiled lua
q{
g = function ()
  local x = 1
  a[1] = { 'b', 'c' }
  w[1] = { 'x', 'y', 'z' }
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2, n do
    x = x * i
  end
  return { a, w }
end
}
],

[ 'Marpa::R2 synopsis as default grammar',
# source LUIF
q{
Script ::= Expression+ % comma
Expression ::=
  Number
  | left_paren Expression right_paren
 || Expression exp Expression
 || Expression mul Expression
  | Expression div Expression
 || Expression add Expression
  | Expression sub Expression
},
# expected: transpiled lua
q{
default_grammar = function()
  Script[1] = { 'Expression',
    fields = {
      proper = 1,
      quantifier = '+',
      separator = 'comma'
    }
  }
  Expression[1] = { 'Number' }
  Expression[2] = { 'left_paren', 'Expression', 'right_paren',
    fields = {
      priority = '|'
    }
  }
  Expression[3] = { 'Expression', 'exp', 'Expression',
    fields = {
      priority = '||'
    }
  }
  Expression[4] = { 'Expression', 'mul', 'Expression',
    fields = {
      priority = '||'
    }
  }
  Expression[5] = { 'Expression', 'div', 'Expression',
    fields = {
      priority = '|'
    }
  }
  Expression[6] = { 'Expression', 'add', 'Expression',
    fields = {
      priority = '||'
    }
  }
  Expression[7] = { 'Expression', 'sub', 'Expression',
    fields = {
      priority = '|'
    }
  }
  return { Script, Expression }
end
}
],

[ 'Marpa::R2 synopsys with actions as explicit grammar',
# source LUIF
q{
Marpa_R2_synopsys_actions = grammar ()
  Script ::= Expression+ % comma
  Expression ::=
    Number
    | left_paren Expression right_paren
   || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
   || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
    | Expression op_div Expression, action (e1, e2) return e1 / e2 end
   || Expression op_add Expression, action (e1, e2) return e1 + e2 end
    | Expression op_sub Expression, action (e1, e2) return e1 - e2 end
end
},
# expected: transpiled lua
q{
Marpa_R2_synopsys_actions = function ()
  Script[1] = { 'Expression',
    fields = {
      proper = 1,
      quantifier = '+',
      separator = 'comma'
    }
  }
  Expression[1] = { 'Number' }
  Expression[2] = { 'left_paren', 'Expression', 'right_paren',
    fields = {
      priority = '|'
    }
  }
  Expression[3] = { 'Expression', 'op_exp', 'Expression',
    fields = {
      action = function (e1, e2) return e1 ^ e2 end,
      priority = '||'
    }
  }
  Expression[4] = { 'Expression', 'op_mul', 'Expression',
    fields = {
      action = function (e1, e2) return e1 * e2 end,
      priority = '||'
    }
  }
  Expression[5] = { 'Expression', 'op_div', 'Expression',
    fields = {
      action = function (e1, e2) return e1 / e2 end,
      priority = '|'
    }
  }
  Expression[6] = { 'Expression', 'op_add', 'Expression',
    fields = {
      action = function (e1, e2) return e1 + e2 end,
      priority = '||'
    }
  }
  Expression[7] = { 'Expression', 'op_sub', 'Expression',
    fields = {
      action = function (e1, e2) return e1 - e2 end,
      priority = '|'
    }
  }
  return { Script, Expression }
end
}
],

[ 'fatal: both grammar() and BNF rules are used, BNF after grammar()',
# source LUIF
q{
g = grammar ()
local x = 1
  a ::= b c
  w ::= x y z
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2,n do
    x = x * i
  end
end
Script ::= Expression+ % comma
Expression ::=
  Number
  | left_paren Expression right_paren
 || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
 || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
  | Expression op_div Expression, action (e1, e2) return e1 / e2 end
 || Expression op_add Expression, action (e1, e2) return e1 + e2 end
  | Expression op_sub Expression, action (e1, e2) return e1 - e2 end
},
q{
...
}
],

[ 'fatal: both grammar() and BNF rules are used, BNF before grammar()',
# source LUIF
q{
Script ::= Expression+ % comma
Expression ::=
  Number
  | left_paren Expression right_paren
 || Expression op_exp Expression, action (e1, e2) return e1 ^ e2 end
 || Expression op_mul Expression, action (e1, e2) return e1 * e2 end
  | Expression op_div Expression, action (e1, e2) return e1 / e2 end
 || Expression op_add Expression, action (e1, e2) return e1 + e2 end
  | Expression op_sub Expression, action (e1, e2) return e1 - e2 end
g = grammar ()
local x = 1
  a ::= b c
  w ::= x y z
  -- not just BNF, but pure Lua statements are allowed in a grammar
  for i = 2,n do
    x = x * i
  end
end
},
q{
...
}
],

[ 'JSON LUIF grammar for Kollos',
q{
            json         ::= object
                           | array
            object       ::= [lcurly rcurly]
                           | [lcurly] members [rcurly]
            members      ::= pair* % comma
            pair         ::= string [colon] value
            value        ::= string
                           | object
                           | number
                           | array
                           | json_true
                           | json_false
                           | null
            array        ::= [lsquare rsquare]
                           | [lsquare] elements [rsquare]
            elements     ::= value+ % comma
            string       ::= lstring
},
q{
default_grammar = function()
  json[1] = { 'object' }
  json[2] = { 'array',
    fields = {
      priority = '|'
    }
  }
  object[1] = { '[', 'lcurly', 'rcurly', ']' }
  object[2] = { '[', 'lcurly', ']', 'members', '[', 'rcurly', ']',
    fields = {
      priority = '|'
    }
  }
  members[1] = { 'pair',
    fields = {
      proper = 1,
      quantifier = '*',
      separator = 'comma'
    }
  }
  pair[1] = { 'string', '[', 'colon', ']', 'value' }
  value[1] = { 'string' }
  value[2] = { 'object',
    fields = {
      priority = '|'
    }
  }
  value[3] = { 'number',
    fields = {
      priority = '|'
    }
  }
  value[4] = { 'array',
    fields = {
      priority = '|'
    }
  }
  value[5] = { 'json_true',
    fields = {
      priority = '|'
    }
  }
  value[6] = { 'json_false',
    fields = {
      priority = '|'
    }
  }
  value[7] = { 'null',
    fields = {
      priority = '|'
    }
  }
  array[1] = { '[', 'lsquare', 'rsquare', ']' }
  array[2] = { '[', 'lsquare', ']', 'elements', '[', 'rsquare', ']',
    fields = {
      priority = '|'
    }
  }
  elements[1] = { 'value',
    fields = {
      proper = 1,
      quantifier = '+',
      separator = 'comma'
    }
  }
  string[1] = { 'lstring' }
  return { json, object, members, pair, value, array, elements, string }
end
}
],

#[ '...', q{...}, q{...} ],
);

for my $test (@tests){

    my ($test_desc, $luif, $expected_lua ) = @$test;

    unless ($test_desc =~ /^fatal/){

        my $transpiled_lua = $p->transpile( $luif );
#        warn $transpiled_lua;

        $expected_lua =~ s/^\s+//ms;
        eq_or_diff $transpiled_lua, $expected_lua, "$test_desc: transpile into lua";

        # transpiled LUIF must compile with lua
        my ($fh, $filename) = tempfile();
        binmode( $fh, ":utf8" );
        say $fh $transpiled_lua;
        my $rc = system "lua $filename";

        is $rc, 0, "$test_desc: compile with lua";

    }
    else{

        eval { $p->transpile( $luif ) };
        my $msg = $@;
        $msg =~ s/single Lua script.*$/single Lua script/ms;

        ok $msg, $msg;

    }
}

done_testing();

