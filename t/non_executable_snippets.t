#!perl
# Copyright 2014 Ruslan Shvedov

#
use 5.10;
use warnings;
use strict;

use Test::More;

use MarpaX::Languages::Lua::AST;

# non-executable snippets which can't be wrapped to a function
# will be tested by comparison with formatted ast

my @tests = (

# strings.lua:103-104
# -------------------
[ q{
-- the below line parses ok
a = '\\\\\\'' -- 1 escaped \ 1 escaped '
-- the below lines are currently misparsed as
-- x = '"нlo"\n\\'
-- assert(string.format(' ...
x = '"нlo"\\n\\\\'
assert(string.format('%q%s', x, x) == '"\\"нlo\\"\\\n\\\\""нlo"\n\\')
}, #'
# expected
q{} ],

# constructs.lua:58
# -----------------
[ q{
local f = function (i)
  if i < 10 then return 'a';
  elseif i < 20 then return 'b';
  elseif i < 30 then return 'c';
  end;
end
},
# expected
q{} ],

# literals.lua:9
# --------------
[ q{
assert('\\n\\"\\'\\\\' == [[

"'\\]]) -- "
}, #"
q{} ],

[ q{ function pow (e1, e2) return e1 ^ e2 end }, q{} ],
#[ q{}, q{} ],
);

my $p = MarpaX::Languages::Lua::AST->new;

TEST:
for my $test (@tests){
    my ($snippet, $expected_fmt) = @{ $test };
    my $ast = $p->parse( $snippet );
    unless (defined $ast){
        $p->parse( $snippet, { trace_terminals => 1 }, { show_progress => 1 } );
        fail "Can't parse:\n$snippet";
        next TEST;
    }

    my $fmt = $p->serialize( $ast );

    my $tokens = $p->tokens( $ast );
    say $tokens;

    TODO: {
        todo_skip <<END, 1 unless $expected_fmt;
AST serialization to formatted source shelved until
lua test suite parsing is done. In a meanwhile, AST serialized to token stream is:\n\n$tokens
END
        is $fmt, $expected_fmt, 'format by serailizing lua code ast';
    }
}

done_testing();

