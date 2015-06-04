#!perl
# Copyright 2014 Ruslan Shvedov

# take a source code of a lua program and test its execution results
# returned by the lua interpreter for the original source code and
# for the source code parsed to AST that is then serialized

# source of programs: http://lua-users.org/wiki/SampleCode

use 5.10;
use warnings;
use strict;

use Test::More;
use File::Spec;

BEGIN {
    my $stderr;
    eval
    {
        my $luav = "lua -v";
        # run $luav capturing STDERR (per perlfaq8)
        use IPC::Open3;
        use File::Spec;
        my $in = '';
        open(NULL, ">", File::Spec->devnull);
        my $pid = open3($in, ">&NULL", \*PH, $luav);
        my $stderr = <PH>;
        waitpid($pid, 0);
        # check lua and its version
        $stderr =~ /^Lua 5.1/ims;
    } or do
    {
        plan skip_all => "lua 5.1 not installed or can't be run (lua -v fails)";
    };
}

use Cwd qw();

use MarpaX::Languages::Lua::AST;

my $p = MarpaX::Languages::Lua::AST->new;


#   file name                       flags:  1 default: do nothing
#                                           2 reparse with diagnostics
#                                           3 reparse and show ast
#                                           4 test stdout with like()
#                                           5 stderr is expected -- test stdout anyway
#                                           7 todo skip

# todo: move this and other in xt (author test)
#       as in http://elliotlovesperl.com/2009/11/24/explicitly-running-author-tests/
# If you have .pm files in your module's distribution
# that are used only for tests, put them in 't/lib' and add the line
#   use lib 't/lib';
# to each test's file.
#   ./xt/author - run when the tests are being run in an author's working copy
#   ./xt/smoke - run when the dist is being smoked (AUTOMATED_TESTING=1)
#   ./xt/release - run during "make disttest"
# -- http://perl-qa.hexten.net/wiki/index.php?title=Best_Practices_for_Testing

my %lua_files = qw{

    api.lua            1
    attrib.lua         1
    big.lua            5
    calls.lua          1
    checktable.lua     1
    closure.lua        7
    code.lua           1
    constructs.lua     1
    db.lua             7
    errors.lua         7
    events.lua         1
    files.lua          4
    gc.lua             1
    literals.lua       1
    locals.lua         1
    main.lua           7
    math.lua           1
    nextvar.lua        1
    pm.lua             1
    sort.lua           4
    strings.lua        1
    vararg.lua         1
    verybig.lua        1
};

# current dir
my $pwd = Cwd::cwd();

# shell script run lua interpreter on ast serialized to tokens
my $run_lua_test = $^O eq 'MSWin32' ? 'run_lua_test.bat' : 'run_lua_test.sh';

# prepend t if running under prove
my @dirs = File::Spec->splitdir( $pwd );
my $under_prove = $dirs[-1] eq 't';
$run_lua_test = File::Spec->catfile( '.', 't', $run_lua_test ) unless $under_prove;
$run_lua_test = './' . $run_lua_test unless $^O eq 'MSWin32';

# test suite dirs
my $lua_test_suite_dir = 'lua5.1-tests';
my $lua_ast_test_suite_dir = 'lua5.1-ast-tests';

# this is used below to silence "Deep recursion warning ... on tokens()"
# todo: check if the recursion is really deep
my $DOWARN = 1;
BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if $DOWARN } }

LUA_FILE:
    for my $lua_fn (sort keys %lua_files){

        # get flags
        my $flag = $lua_files{$lua_fn};

        # prepend test suite path unless a file is from another dir
        my $lua_ts_fn = File::Spec->catfile( $lua_test_suite_dir, $lua_fn );
        my $lua_ast_ts_fn = File::Spec->catfile( $lua_ast_test_suite_dir, $lua_fn );

        # prepend t if running under prove
        $lua_ts_fn = File::Spec->catfile( 't', $lua_ts_fn ) unless $under_prove;
        $lua_ast_ts_fn = File::Spec->catfile( 't', $lua_ast_ts_fn ) unless $under_prove;

TODO: {
        todo_skip "$lua_fn parses, but runs incorrectly", 1  if $flag == 7;

        # As an example, consider the following code:
        my $lua_slurp = slurp_file( $lua_ts_fn );

        # When you run it, it produces the following output:
        my $expected_stdout = slurp_file( qq{$lua_ts_fn.out} );

        # parse
        my $ast = $p->parse($lua_slurp);
        # check for parse error, fail and proceed as flagged if any
        unless (defined $ast){
            fail "parse $lua_ts_fn";
            if ($flag eq 2){ # reparse with diagnostics
                $ast = $p->parse(
                    $lua_slurp,
                    { trace_terminals => 1 },
                    { show_progress => 1 }
                    );
            }
            next LUA_FILE;
        }

        # serialize ast to tokens and write to temporary file
$DOWARN = 0; # see above
        my $parsed_lua_source = $p->fmt($ast);
$DOWARN = 1;
        whip_up_lua_file( $lua_ast_ts_fn, $parsed_lua_source );
        diag "Serialized AST is in $lua_ast_ts_fn file" if $flag == 6;
        # run lua file
        system("$run_lua_test $lua_ast_test_suite_dir $lua_fn 1>$lua_ast_ts_fn.stdout 2>$lua_ast_ts_fn.stderr");
        my ($stdout, $stderr) = map { slurp_file($_) } qq{$lua_ast_ts_fn.stdout}, qq{$lua_ast_ts_fn.stderr};

        # check for run error, fail and proceed as flagged if any
        if
        (
                $stderr         # there was run error
            and $flag != 5      # and it is NOT expected
        ){
            fail "$run_lua_test $lua_ast_test_suite_dir $lua_fn:\n$stderr";
            if ($flag eq 3){ # reparse and show ast
                $ast = $p->parse( $lua_slurp );
                warn "# ast of $lua_ts_fn: ", $p->serialize( $ast );
            }
            next LUA_FILE;
        }
        # file parses and runs, test its output
        if ($flag == 4){
            # turn $expected_stdout to a regex and test against it
            if ( $lua_ts_fn =~ m{ sort.lua$ }x ){
                $expected_stdout =~ s{[\d\.]+}{[\\d\\.]+}gx;
                like $stdout, qr/$expected_stdout/, $lua_ts_fn;
                next LUA_FILE;
            }
            elsif ( $lua_ts_fn =~ m{ files.lua$ }x ){
                $expected_stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
                $expected_stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
                $stdout =~ s{\d{2}/\d{2}/\d{4}}{__DATE__}gx;
                $stdout =~ s{\d{2}:\d{2}:\d{2}}{__TIME__}gx;
                is $stdout, $expected_stdout, $lua_ts_fn;
                next LUA_FILE;
            }
        }
        is $stdout, $expected_stdout, $lua_ts_fn;
}

} ## for my $lua_fn (@lua_files){

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

sub whip_up_lua_file{
    my ($lua_fn, $lua_text) = @_;
    open my $fh, ">$lua_fn" or die "Can't create $lua_fn: $@.";
    say $fh $lua_text;
    close $fh;
}

done_testing();


