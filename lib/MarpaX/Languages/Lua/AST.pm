# Copyright 2014 Ruslan Shvedov

# Lua 5.1 Parser in barebones (no priotitized rules, external scanning) SLIF

package MarpaX::Languages::Lua::AST;

use 5.010;
use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Deepcopy = 1;

use Marpa::R2;

# Lua Grammar
# ===========

my $grammar = q{

:default ::= action => [ name, values ]
lexeme default = action => [ name, value ] latm => 1

    # source: 8 – The Complete Syntax of Lua, Lua 5.1 Reference Manual
    # discussion on #marpa -- http://irclog.perlgeek.de/marpa/2014-10-06#i_9463520
    #    -- http://www.lua.org/manual/5.1/manual.html
    # The Lua Book -- http://www.lua.org/pil/contents.html
    # More parser tests: http://lua-users.org/wiki/LuaGrammar

    # {a} means 0 or more a's, and [a] means an optional a
    # * -- 0 or more: { ... }
    # ? -- 0 or 1:    [ ... ]

    # keywords and lexemes are symbols in <> having no spaces
    # original rules are commented if converted; what follows is their converted form
    # Capitalized symbols (Name) are from the lua grammar cited above

#    chunk ::= {stat [';']} [laststat [';']]
# e.g. function () end, api.lua:126
    chunk ::=
    chunk ::= statements
    chunk ::= statements laststat
    chunk ::= statements laststat <semicolon>
    chunk ::= laststat <semicolon>
    chunk ::= laststat
#    {stat [';']}
    statements ::= stat
    statements ::= statements stat
    statements ::= statements <semicolon> stat
#   [';'] from {stat [';']}
#   not in line with "There are no empty statements and thus ';;' is not legal"
#   in http://www.lua.org/manual/5.1/manual.html#2.4.1, but api.lua:163
#   doesn't parse without that
#   there is also constructs.lua:58 -- end;
#
#   possible todo: better optional semicolon
    stat ::= <semicolon>

    block ::= chunk

    stat ::= varlist <assignment> explist

    stat ::= functioncall

    stat ::= <do> block <end>
    stat ::= <while> exp <do> block <end>
    stat ::= <repeat> block <until> exp

#    <if> exp <then> block {<elseif> exp <then> block} [<else> block] <end> |
    stat ::= <if> exp <then> block <end>
    stat ::= <if> exp <then> block <else> block <end>
    stat ::= <if> exp <then> block <one or more elseifs> <else> block <end>
    stat ::= <if> exp <then> block <one or more elseifs> <end>

#    <for> Name <assignment> exp ',' exp [',' exp] <do> block <end> |
    stat ::= <for> Name <assignment> exp <comma> exp <comma> exp <do> block <end>
    stat ::= <for> Name <assignment> exp <comma> exp <do> block <end>
    stat ::= <for> namelist <in> explist <do> block <end>

    stat ::= <function> funcname funcbody

    stat ::= <local> <function> Name funcbody

#    <local> namelist [<assignment> explist]
    stat ::= <local> namelist <assignment> explist
    stat ::= <local> namelist

    <one or more elseifs> ::= <one elseif>
    <one or more elseifs> ::= <one or more elseifs> <one elseif>
    <one elseif> ::= <elseif> exp <then> block

#    laststat ::= <return> [explist] | <break>
    laststat ::= <return>
    laststat ::= <return> explist
    laststat ::= <break>

#    funcname ::= Name {'.' Name} [':' Name]
    funcname ::= names <colon> Name
    funcname ::= names
#    Names ::= Name+ separator => [\.]
    names ::= Name | names <period> Name

#    varlist ::= var {',' var}
#    varlist ::= var+ separator => [,]
    varlist ::= var | varlist <comma> var

    var ::=  Name | prefixexp <left bracket> exp <right bracket> | prefixexp <period> Name

#    namelist ::= Name {',' Name}
#    namelist ::= Name+ separator => [,]
    namelist ::= Name
    namelist ::= namelist <comma> Name

#    explist ::= {exp ','} exp
#    explist ::= exp+ separator => [,]
    explist ::= exp
    explist ::= explist <comma> exp


    exp ::= <nil>
    exp ::= <false>
    exp ::= <true>
    exp ::= Number
    exp ::= String
    exp ::= <ellipsis>
    exp ::= functionexp
    exp ::= prefixexp
    exp ::= tableconstructor
    exp ::= exp binop exp
    exp ::= unop exp

    prefixexp ::= var
    prefixexp ::= functioncall
    prefixexp ::= <left paren> exp <right paren>

    functioncall ::= prefixexp args
    functioncall ::= prefixexp <colon> Name args

#    args ::=  '(' [explist] ')' | tableconstructor | String
    args ::= <left paren> <right paren>
    args ::= <left paren> explist <right paren>
    args ::= tableconstructor
    args ::= String

    functionexp ::= <function> funcbody

#    funcbody ::= '(' [parlist] ')' block <end>
    funcbody ::= <left paren> parlist <right paren> block <end>
    funcbody ::= <left paren> <right paren> block <end>

#    parlist ::= namelist [',' '...'] | '...'
    parlist ::= namelist
    parlist ::= namelist <comma> <ellipsis>
    parlist ::= <ellipsis>

#    tableconstructor ::= '{' [fieldlist] '}'
    tableconstructor ::= <left curly> fieldlist <right curly>
    tableconstructor ::= <left curly> <right curly>

#    fieldlist ::= field {fieldsep field} [fieldsep]
    fieldlist ::= field
    fieldlist ::= fieldlist fieldsep field
    fieldlist ::= fieldlist fieldsep field fieldsep

    fieldsep ::= <comma>
    fieldsep ::= <semicolon>

    field ::= <left bracket> exp <right bracket> <assignment> exp
    field ::= Name <assignment> exp
    field ::= exp

#   binary operators
    binop ::= <addition>
    binop ::= <minus>
    binop ::= <multiplication>
    binop ::= <division>
    binop ::= <exponentiation>
    binop ::= <percent>
    binop ::= <concatenation>
    binop ::= <less than>
    binop ::= <less or equal>
    binop ::= <greater than>
    binop ::= <greater or equal>
    binop ::= <equality>
    binop ::= <negation>
    binop ::= <and>
    binop ::= <or>

#   unary operators
    unop ::= <minus>
    unop ::= <not>
    unop ::= <length>

#   unicorns
    # unicorn rules will be added in the constructor for extensibility
    unicorn ~ [^\s\S]

};

my @unicorns = (

    'String',
    'Number',
    'Name',

    '<addition>',
    '<and>',
    '<assignment>',
    '<break>',
    '<colon>',
    '<comma>',
    '<concatenation>',
    '<division>',
    '<do>',
    '<ellipsis>',
    '<else>',
    '<elseif>',
    '<end>',
    '<equality>',
    '<exponentiation>',
    '<false>',
    '<for>',
    '<function>',
    '<greater or equal>',
    '<greater than>',
    '<if>',
    '<in>',
    '<left bracket>',
    '<left curly>',
    '<left paren>',
    '<length>',
    '<less or equal>',
    '<less than>',
    '<local>',
    '<minus>',
    '<multiplication>',
    '<negation>',
    '<nil>',
    '<not>',
    '<or>',
    '<percent>',
    '<period>',
    '<repeat>',
    '<return>',
    '<right bracket>',
    '<right curly>',
    '<right paren>',
    '<semicolon>',
    '<then>',
    '<true>',
    '<until>',
    '<while>',
);

# Terminals
# =========

# group matching regexes

# keywords
my @keywords = qw {
    and break do else elseif end false for function if in local nil not
    or repeat return then true until while
};

my $keywords = { map { $_ => $_ } @keywords };

# operators, punctuation
my $op_punc = {
            '...' =>'ellipsis',         '..' => 'concatenation',

            '<=' => 'less or equal',    '>=' => 'greater or equal',
            '~=' => 'negation',         '==' => 'equality',

            '.' =>  'concatenation',    '<' =>  'less than',
            '>' =>  'greater than',     '+' =>  'addition',
            '-' =>  'minus',            '*' =>  'multiplication',
            '/' =>  'division',         '%' =>  'percent',
            '#' =>  'length',           '^' =>  'exponentiation',
            ':' =>  'colon',            '[' =>  'left bracket',
            ']' =>  'right bracket',    '(' =>  'left paren',
            ')' =>  'right paren',      '{' =>  'left curly',
            '}' =>  'right curly',      '=' =>  'assignment',
            ';' =>  'semicolon',        ',' =>  'comma',
            '.' =>  'period',
};

# terminals are regexes and strings
my @terminals = ( # order matters!

#   comments -- short, long (nestable)
    [ 'Comment' => qr/--\[(={4,})\[.*?\]\1\]/xms,   "long nestable comment" ],
    [ 'Comment' => qr/--\[===\[.*?\]===\]/xms,      "long nestable comment" ],
    [ 'Comment' => qr/--\[==\[.*?\]==\]/xms,        "long nestable comment" ],
    [ 'Comment' => qr/--\[=\[.*?\]=\]/xms,          "long nestable comment" ],
    [ 'Comment' => qr/--\[\[.*?\]\]/xms,            "long unnestable comment" ],
    [ 'Comment' => qr/--[^\n]*\n/xms,               "short comment" ],

#   strings -- short, long (nestable)
# 2.1 – Lexical Conventions, refman
# Literal strings can be delimited by matching single or double quotes, and can contain the
# following C-like escape sequences: '\a' (bell), '\b' (backspace), '\f' (form feed), '\n' (
# newline), '\r' (carriage return), '\t' (horizontal tab), '\v' (vertical tab), '\\'
# (backslash), '\"' (quotation mark [double quote]), and '\'' (apostrophe [single quote]).
# Moreover, a backslash followed by a real newline results in a newline in the string. A
# character in a string can also be specified by its numerical value using the escape sequence
# \ddd, where ddd is a sequence of up to three decimal digits. (Note that if a numerical escape
# is to be followed by a digit, it must be expressed using exactly three digits.) Strings in
# Lua can contain any 8-bit value, including embedded zeros, which can be specified as '\0'.

    [ 'String' => qr
        /'(
            \\(a|b|f|n|r|t|v|"|'|\\) | [^']
           )*
         '/xms, "single quoted string" ],

    [ 'String' => qr
        /"(
            \\(a|b|f|n|r|t|v|"|'|\\) | [^"]
           )*
         "/xms, "double quoted string" ],
#'
    [ 'String' => qr/\[\[.*?\]\]/xms,           "long unnestable string" ],
    [ 'String' => qr/\[=\[.*?\]=\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[==\[.*?\]==\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[===\[.*?\]===\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[====\[.*?\]====\]/xms,         "long nestable string" ],
    [ 'String' => qr/\[(={5,})\[.*?\]\1\]/xms,     "long nestable string" ],

#   numbers -- int, float, and hex
#   We can write numeric constants with an optional decimal part,
#   plus an optional decimal exponent -- http://www.lua.org/pil/2.3.html
    [ 'Number' => qr/[0-9]+\.?[0-9]+([eE][-+]?[0-9]+)?/xms, "Floating-point number" ],
    [ 'Number' => qr/[0-9]+[eE][-+]?[0-9]+/xms, "Floating-point number" ],
    [ 'Number' => qr/[0-9]+\./xms, "Floating-point number" ],
    [ 'Number' => qr/\.[0-9]+/xms, "Floating-point number" ],
    [ 'Number' => qr/0x[0-9a-fA-F]+/xms, "Hexadecimal number" ],
    [ 'Number' => qr/[\d]+/xms, "Integer number" ],

#   identifiers
    [ 'Name' => qr/\b[a-zA-Z_][\w]*\b/xms, "Name" ],

);

sub terminals{

#   keywords -- group matching
    $keywords = { map { $_ => $_ } @keywords };
    my $keyword_re = '\b' . join( '\b|\b', @keywords ) . '\b';

    push @terminals, [ $keywords => qr/$keyword_re/xms ];

#   operators and punctuation -- group matching -- longest to shortest, quote and alternate
    my $op_punc_re = join '|', map { quotemeta } sort { length($b) <=> length($a) }
        keys $op_punc;

    push @terminals, [ $op_punc => qr/$op_punc_re/xms ];

    return \@terminals;
}

# add unicorns to grammar source and construct the grammar
sub grammar{
    my ($extension) = @_;
    $extension //= '';
    my $source = $grammar . "\n### extension rules ###" . $extension . "\n" . join( "\n", map { qq{$_ ~ unicorn} } @unicorns ) . "\n";
    return Marpa::R2::Scanless::G->new( { source => \$source } );
}

sub new {
    my ($class) = @_;
    my $parser = bless {}, $class;
    $parser->{grammar} = grammar();
    return $parser;
}

sub extend{
    my ($parser, $opts) = @_;

    my $rules = $opts->{rules};

    # todo: this is quick hack, use metag.bnf

    # add new literals and unicorns
    for my $literal (keys $opts->{literals}){
        my $symbol = $opts->{literals}->{$literal};
#        say "new literal: $symbol, $literal";
        $op_punc->{$literal} = $symbol;
        $symbol = qq{<$symbol>} if $symbol =~ / /;
        push @unicorns, $symbol;
    }

    # replace known literals to lexemes
    my %literals = map { $_ => undef } $rules =~ m/'([^\#'\n]+)'/gms; #'
    while (my ($literal, undef) = each %literals){
        my $symbol = $op_punc->{$literal};
        if (defined $symbol){
            $symbol = qq{<$symbol>} if $symbol =~ / /;
            # remove L0 rules if any
            $rules =~ s/<?[\w_ ]+>?\s*~\s*'\Q$literal\E'\n?//ms; #'
            # replace known literals with symbols
            $rules =~ s/'\Q$literal\E'/$symbol/gms;
            delete $literals{$literal};
        }
    }

    # find symbol ~ '...' L0 rules and see if they have names for unknown literals
    # todo: the same thing for character classes once/if general lexing
    # (https://gist.github.com/rns/2ae390a2c7d235687287) is supported

#    say "# unknown literals:\n  ", join "\n  ", keys %literals;
    my @L0_rules = $rules =~ m/<?([\w_ ]+)>?\s*~\s*'([^\#'\n]+)'/gms; #'
    for(my $ix = 0; $ix <= $#L0_rules; $ix += 2) {
        my $symbol = $L0_rules[$ix];
        $symbol =~ s/\s+$//;
        my $literal = $L0_rules[$ix + 1];
#        say "<$symbol> ~ '$literal'";
        # add symbol and literal to external lexing
        $op_punc->{$literal} = $symbol;
        # remove L0 rule
        $rules =~ s/<?$symbol>?\s*~\s*'\Q$literal\E'\n?//ms; #'
        # add new symbol as unicorn
        $symbol = qq{<$symbol>} if $symbol =~ / /;
        push @unicorns, $symbol;
        # now we know the literal
        delete $literals{$literal};
    }
    # todo: support charclasses?

    die "# unknown literals:\n  ", join "\n  ", keys %literals if keys %literals;

    # terminals for external lexing will be rebuilt when parse()
    # now append $rules and try to create new grammar
    $parser->{grammar} = grammar( $rules );
}

sub read{
    my ($parser, $recce, $string) = @_;

    # strip 'special comment on the first line'
    # todo: filter should preserve this
    $string =~ s{^#.*\n}{};

    $recce->read( \$string, 0, 0 );

    # build terminals
    my @terminals = @{ terminals() };

    my $length = length $string;
    pos $string = 0;
    TOKEN: while (1) {
        my $start_of_lexeme = pos $string;
        last TOKEN if $start_of_lexeme >= $length;
        next TOKEN if $string =~ m/\G\s+/gcxms;     # skip whitespace
#        warn "# matching at $start_of_lexeme:\n", substr( $string, $start_of_lexeme, 40 );
        TOKEN_TYPE: for my $t (@terminals) {


            my ( $token_name, $regex, $long_name ) = @{$t};
            next TOKEN_TYPE if not $string =~ m/\G($regex)/gcxms;
            my $lexeme = $1;
            # Name cannot be a keyword so treat strings matching Name's regex as keywords
            if ( $token_name eq "Name" and exists $keywords->{$lexeme} ){
                $token_name = $keywords->{$lexeme};
                $long_name = $token_name;
            }
            # check for group matching
            if (ref $token_name eq "HASH"){
                $token_name = $token_name->{$lexeme};
                die "No token defined for lexeme <$lexeme>"
                    unless $token_name;
                $long_name = $token_name;
            }

            # skip comments
            next TOKEN if $token_name =~ /comment/i;

#            warn "# <$token_name>:\n'$lexeme'";
            if ( not defined $recce->lexeme_alternative($token_name) ) {
                warn
                    qq{Parser rejected token "$long_name" at position $start_of_lexeme, before "},
                    substr( $string, $start_of_lexeme + length($lexeme), 40 ), q{"};
                warn "Showing progress:\n", $recce->show_progress();
                return
            }
            next TOKEN
                if $recce->lexeme_complete( $start_of_lexeme,
                        ( length $lexeme ) );

        } ## end TOKEN_TYPE: for my $t (@terminals)
        warn qq{No token found at position $start_of_lexeme, before "},
            substr( $string, pos $string, 40 ), q{"};
#        warn "Showing progress:\n", $recce->show_progress();
        return
    } ## end TOKEN: while (1)
    # return ast or undef on parse failure
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        warn "No parse was found, after reading the entire input.\n";
#        warn "Showing progress:\n", $recce->show_progress();
        return
    }
    return ${$value_ref};
}

sub parse {
    my ( $parser, $source, $recce_opts ) = @_;
    # add grammar
    $recce_opts->{grammar} = $parser->{grammar};
    my $recce = Marpa::R2::Scanless::R->new( $recce_opts );
    return $parser->read($recce, $source);
} ## end sub parse

sub serialize{
    my ($parser, $ast) = @_;
    state $depth++;
    my $s;
    my $indent = "  " x ($depth - 1);
    if (ref $ast){
        my ($node_id, @children) = @$ast;
        if (@children == 1 and not ref $children[0]){
            $s .= $indent . "$node_id '$children[0]'" . "\n";
        }
        else{
            $s .= $indent . "$node_id\n";
            $s .= join '', map { $parser->serialize( $_ ) } @children;
        }
    }
    else{
        $s .= $indent . "'$ast'"  . "\n";
    }
    $depth--;
    return $s;
}

# quick hack to test against Inline::Lua:
# serialize $ast to a stream of tokens separated with a space
sub tokens{
    my ($parser, $ast) = @_;
    my $tokens;
    if (ref $ast){
        my ($node_id, @children) = @$ast;
        $tokens .= join q{}, grep { defined } map { $parser->tokens( $_ ) } @children;
    }
    else{
        my $separator = ' ';
        if ( # no spaces before and after ' and "
               (defined $tokens and $tokens =~ m{['"\[]$}ms) #'
            or (defined $ast    and $ast    =~ m{^['"\]]}ms) #'
        ){
            $separator = '';
        }
        if (defined $ast and $ast =~ /^(and|or|assert|function|while|repeat|return|do|if|end|else|elseif|for|local)$/){
            $separator = "\n";
        }
        $tokens .= $separator . $ast if defined $ast;
        $tokens .= "\n" if defined $ast and $ast eq 'end';
    }
    return $tokens;
}

1;
