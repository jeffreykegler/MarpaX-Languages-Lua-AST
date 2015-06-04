#!perl
# Copyright 2014 Ruslan Shvedov

# test parsing of lua code snippets from the Reference manual

use 5.10;
use warnings;
use strict;

use Test::More;

use Inline 0.77;

BEGIN {
    my $ilv = '0.09';
    eval {
        require Inline::Lua;
        $Inline::Lua::VERSION >= $ilv;
    } or do
    {
        plan skip_all => "Inline::Lua $ilv is not installed";
    };
}

use MarpaX::Languages::Lua::AST;

# evaluate snippet: it can be arbitrary, just make sure that
# the return value is in variable a before the function end
my @tests;

BEGIN {
    my @a = (
# the five literal strings below denote the same string:
# todo: test the 5 snippets below for "the same string"
        q{ a = 'alo\n123"'       },
        q{ a = "alo\n123\""      },
        q{ a = '\97lo\10\04923"' },
        q{ a = [[alo
               123"]]
        },
        q{ a = [==[
                alo
                123"]==]
        },
# strings.lua:103-104, see pod below
# \ is escaped to \\ in the below lines to pass the test
        q{ a = '"нlo"\\n\\\\'     },
        q{ a = '"\\\\"нlo\\\\"\\\\\\n\\\\\\\\""нlo"\\n\\\\' },
# Examples of valid numerical constants are
        q{ a = 3           },
        q{ a = 3.0         },
        q{ a = 3.          },
        q{ a = 3.1416      },
        q{ a = .14         },
        q{ a = 10e30       },
        q{ a = 314.16e-2   },
        q{ a = 0.31416E1   },

        q{ a = 0xff        },
        q{ a = 0x56        },
# literals.lua:129
        q{ a = [====[[===[[=[]]=][====[]]===]===]====] },
# main.lua:113
        q{
a = [=[ --
function f ( x )
  local a = [[
xuxu
]]
  local b = "\
xuxu\n"
  if x == 11 then return 1 , 2 end  --[[ test multiple returns ]]
  return x + 1
  --\\
end
=( f( 10 ) )
assert( a == b )
=f( 11 )  ]=]
},
# api.lua:163
        q{ a = 1, function (a) assert(a==nil); return 3 end },
    );
    for my $i (0..$#a){
        push @tests, [
            'function a_inline_' . $i . '() ' . $a[$i] . ' return a end',
            'function a_parsed_' . $i . '() ' . $a[$i] . ' return a end',
            $a[$i] # snippet
        ];
    }
}

my @results;
my $compile_template = q{
    use Inline Lua => $tests[{{i}}]->[0];
    my $expected_a{{i}} = a_inline_{{i}}();

    sub got_a{{i}}{
        my $ast = $p->parse($tests[{{i}}]->[1]);
        my $tokens = $p->tokens( $ast );
        push @results, $tokens; # save serialized ast to show if test fails
        return $tokens;
    }

    use Inline Lua => &got_a{{i}};
    my $got_a{{i}} = a_parsed_{{i}}();

    push @results, $got_a{{i}}, $expected_a{{i}}; # save lua execution resutls
};

my $p;
BEGIN {
    $p = MarpaX::Languages::Lua::AST->new;
}

for my $i (0..$#tests){
    my $compile_i = $compile_template;
    $compile_i =~ s/{{i}}/$i/g;
    eval $compile_i;
    if ($@){ # misparsing: reparse to show why
        my $ast = $p->parse(
            $tests[$i]->[2],
            { trace_terminals => 0 },
            { show_progress => 0 }
        );
        if (defined $ast){
            fail $tests[$i]->[2];
            my $tokens = $p->tokens( $ast );
            print STDERR '# ';
            my $rc = system "lua", '-e', $tokens;
            if ($rc != 0){
                diag "<$tests[$i]->[2]>\nmisparsed as\n<$tokens>";
            }
        }
    }
    else{
        is $results[1], $results[2], $tests[$i]->[2];
    }
    @results = ();
}

done_testing();

__END__
=pod


# The assignment statement first evaluates all its expressions
# and only then are the assignments performed. Thus the code
     i = 3
     i, a[i] = i+1, 20
sets a[3] to 20, without affecting a[4] because the i in a[i] is evaluated (to 3) before it is assigned 4.

# Similarly, the line
     x, y = y, x
exchanges the values of x and y, and
     x, y, z = y, z, x
cyclically permutes the values of x, y, and z.


# The block is repeated for name starting at the value of the first exp,
# until it passes the second exp by steps of the third exp.
# More precisely, a for statement like

     for v = e1, e2, e3 do block end

is equivalent to the code:

     do
       local var, limit, step = tonumber(e1), tonumber(e2), tonumber(e3)
       if not (var and limit and step) then error() end
       while (step > 0 and var <= limit) or (step <= 0 and var >= limit) do
         local v = var
         block
         var = var + step
       end
     end

# A for statement like

     for var_1, ···, var_n in explist do block end

is equivalent to the code:

     do
       local f, s, var = explist
       while true do
         local var_1, ···, var_n = f(s, var)
         var = var_1
         if var == nil then break end
         block
       end
     end

# Here are some examples:

     f()                -- adjusted to 0 results
     g(f(), x)          -- f() is adjusted to 1 result
     g(x, f())          -- g gets x plus all results from f()
     a,b,c = f(), x     -- f() is adjusted to 1 result (c gets nil)
     a,b = ...          -- a gets the first vararg parameter, b gets
                        -- the second (both a and b can get nil if there
                        -- is no corresponding vararg parameter)

     a,b,c = x, f()     -- f() is adjusted to 2 results
     a,b,c = f()        -- f() is adjusted to 3 results
     return f()         -- returns all results from f()
     return ...         -- returns all received vararg parameters
     return x,y,f()     -- returns x, y, and all results from f()
     {f()}              -- creates a list with all results from f()
     {...}              -- creates a list with all vararg parameters
     {f(), nil}         -- f() is adjusted to 1 result

# Modulo is defined as

     a % b == a - math.floor(a/b)*b

# The negation operator not always returns false or true.
# The conjunction operator and returns its first argument
# if this value is false or nil; otherwise, and returns its second argument.
# The disjunction operator or returns its first argument
# if this value is different from nil and false; otherwise,
# or returns its second argument. Both and and or use short-cut evaluation;
# that is, the second operand is evaluated only if necessary. Here are some examples:

     10 or 20            --> 10
     10 or error()       --> 10
     nil or "a"          --> "a"
     nil and 10          --> nil
     false and error()   --> false
     false and nil       --> false
     false or nil        --> nil
     10 and 20           --> 20


Table constructors are expressions that create tables. Every time a constructor is evaluated, a new table is created. A constructor can be used to create an empty table or to create a table and initialize some of its fields. The general syntax for constructors is

    tableconstructor ::= `{? [fieldlist] `}?
    fieldlist ::= field {fieldsep field} [fieldsep]
    field ::= `[? exp `]? `=? exp | Name `=? exp | exp
    fieldsep ::= `,? | `;?


# Each field of the form [exp1] = exp2 adds to the new table an entry with key exp1 and value exp2. A field of the form name = exp is equivalent to ["name"] = exp. Finally, fields of the form exp are equivalent to [i] = exp, where i are consecutive numerical integers, starting with 1. Fields in the other formats do not affect this counting. For example,

     a = { [f(1)] = g; "x", "y"; x = 1, f(x), [30] = 23; 45 }

is equivalent to

     do
       local t = {}
       t[f(1)] = g
       t[1] = "x"         -- 1st exp
       t[2] = "y"         -- 2nd exp
       t.x = 1            -- t["x"] = 1
       t[3] = f(x)        -- 3rd exp
       t[30] = 23
       t[4] = 45          -- 4th exp
       a = t
     end

# If you write

     a = f
     (g).x(a)

Lua would see that as a single statement, a = f(g).x(a).
So, if you want two statements, you must add a semi-colon between them.
If you actually want to call f, you must remove the line break before (g).

# none of the following examples are tail calls:

     return (f(x))        -- results adjusted to 1
     return 2 * f(x)
     return x, f(x)       -- additional results
     f(x); return         -- results discarded
     return x or f(x)     -- results adjusted to 1

# The statement

     function f () body end

translates to

     f = function () body end

# The statement

     function t.a.b.c.f () body end

translates to

     t.a.b.c.f = function () body end

# The statement

     local function f () body end

translates to

     local f; f = function () body end

not to

     local f = function () body end

# As an example, consider the following definitions:

     function f(a, b) end
     function g(a, b, ...) end
     function r() return 1,2,3 end

# The colon syntax is used for defining methods, that is,
# functions that have an implicit extra parameter self.
# Thus, the statement

     function t.a.b.c:f (params) body end

is syntactic sugar for

     t.a.b.c.f = function (self, params) body end

# Lua is a lexically scoped language.
# The scope of variables begins at the first statement
# after their declaration and lasts until the end of the innermost block
# that includes the declaration. Consider the following example:

     x = 10                -- global variable
     do                    -- new block
       local x = x         -- new 'x', with value 10
       print(x)            --> 10
       x = x+1
       do                  -- another block
         local x = x+1     -- another 'x'
         print(x)          --> 12
       end
       print(x)            --> 11
     end
     print(x)              --> 10  (the global one)

# Notice that each execution of a local statement defines new local variables.
# Consider the following example:

     a = {}
     local x = 20
     for i=1,10 do
       local y = 0
       a[i] = function () y=y+1; return x+y end
     end

The loop creates ten closures (that is, ten instances of the anonymous function).
Each of these closures uses a different y variable, while all of them share the same x.

# More formally, we define an acceptable index as follows:

     (index < 0 && abs(index) <= top) ||
     (index > 0 && index <= stackspace)

# the host program can do the equivalent to this Lua code:

     a = f("how", t.x, 14)

loadstring (string [, chunkname]) can be used to test snippets

Similar to load, but gets the chunk from the given string.

To load and run a given string, use the idiom

     assert(loadstring(s))()
When absent, chunkname defaults to the given string.

=cut
