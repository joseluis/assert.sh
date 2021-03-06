#!/bin/bash

. assert.sh

assert "echo"                           # no output expected
assert "echo foo" "foo"                 # output expected
assert "cat" "bar" "bar"                # output expected if input's given
assert_raises "true" 0 ""               # status code expected
assert_raises "exit 127" 127 ""         # status code expected
assert "head -1 < $0" "#!/bin/bash"     # redirections
assert "seq 2" "1\n2"                   # multi-line output expected
assert_raises 'read a; exit $a' 42 "42" # variables still work
assert "echo 1;
echo 2      # ^" "1\n2"                 # semicolon required!
assert 'echo " * "' " * "               # don't let the shell evaluate arguments
assert "echo '%s --'" "%s --"           # don't escape user content
assert "echo \"foo\nbar\"" "foo\nbar"   # interpretation of backslash escape
assert_end demo

_clean() {
    _assert_reset # reset state
    DEBUG= STOP= INVARIANT=1 DISCOVERONLY= CONTINUE= # reset flags
    eval $* # read new flags
}

# clean output
assert "_clean; assert true; assert_end" \
"all 1 tests passed."
# error reports on failure
assert "_clean; assert 'seq 1'; assert_end" \
'test #1 "seq 1" failed:\n\texpected nothing\n\tgot "1"\n1 of 1 tests failed.'
assert "_clean; assert true '1'; assert_end" \
'test #1 "true" failed:\n\texpected "1"\n\tgot nothing\n1 of 1 tests failed.'
assert "_clean; assert 'true' 'foo' 'bar'; assert_end" \
'test #1 "true <<< bar" failed:\n\texpected "foo"\n\tgot nothing\n1 of 1 tests failed.'
# debug output (-v)
assert "_clean DEBUG=1; assert true; assert_end" \
".\nall 1 tests passed."
assert "_clean DEBUG=1; assert_raises false; assert_end" \
'X\ntest #1 "false" failed:\n\tprogram terminated with code 1 instead of 0
1 of 1 tests failed.'
# collect tests only (-d)
assert "_clean DISCOVERONLY=1; assert true; assert false; assert_end" \
"collected 2 tests."
# stop immediately on failure (-x)
assert "_clean STOP=1; assert_raises false; assert_end" \
'test #1 "false" failed:\n\tprogram terminated with code 1 instead of 0'
# runtime statistics (omission of -i)
assert_raises "_clean INVARIANT=;
assert_end | egrep 'all 0 tests passed in ([0-9]|[0-9].[0-9]{3})s'"
# always exit successfully (--continue)
assert_raises "bash -c '. assert.sh; assert_raises false; assert_end' '' --continue" 0
# skip
assert "_clean; skip; assert_raises false; assert_raises true; assert_end" \
"all 1 tests passed."
# conditional skip
assert "_clean; skip_if true; assert_raises false; assert_end;" \
"all 0 tests passed."
assert "_clean; skip_if false; assert_raises true; assert_end;" \
"all 1 tests passed."
assert "_clean; skip_if bash -c 'exit 1'; assert_raises false; assert_end;" \
"all 0 tests passed."
# subshells and pipes can be used in skip as well (albeit escaped)
assert "_clean; skip_if 'id | grep \$(echo \$USER)';
assert_raises false; assert_end;" \
"all 0 tests passed."
assert_end output

# stderr should NOT leak if ignored
assert "_clean; assert less" ""
# stderr should be redirectable though
assert '_clean; assert "less 2>&1" "Missing filename (\"less --help\" for help)"'
# bash failures behave just like stderr
assert "_clean; assert ___invalid" ""
# test suites can be nested and settings are inherited
# (ie. we don't need to invoke the inner suite with the very same options,
# namely --invariant)
assert "_clean; bash -c '
. assert.sh;
assert_raises true; assert_end outer;
bash -c \". assert.sh; assert_raises true; assert_end inner\"
' '<exec>' --invariant" "all 1 outer tests passed.
all 1 inner tests passed."  # <exec> is $0
# set the correct exit status
assert_raises "_clean; bash -c \"
. assert.sh; assert true ''; assert_end one;
assert 'echo bar' 'bar'; assert_end two\"" 0
assert_raises "_clean; bash -c \"
. assert.sh; assert true 'foo'; assert_end one;
assert 'echo bar' 'bar'; assert_end two\"" 1
# ..but do not override it
assert_raises "_clean; bash -c \"
. assert.sh; assert true 'foo'; assert_end one;
assert 'echo bar' 'bar'; assert_end two; exit 3\"" 3
# environment variables do not leak
assert "_clean; x=0; assert 'x=1'; assert_raises 'x=2'; echo \$x" 0
assert "_clean; x=0; assert 'export x=1'; assert_raises 'export x=2';
echo \$x" 0
# options do not leak
assert_raises "shopt -o errexit" 1
assert_raises "set -e"
assert_raises "shopt -o errexit" 1
# skip properly resets all options
assert_raises "_clean; set +e; skip; assert_raises false; shopt -o errexit" 1
assert_raises "_clean; set -e; skip; assert_raises false; shopt -o errexit"
assert_raises "_clean; shopt -u extdebug; skip; assert_raises false; shopt extdebug" 1
assert_raises "_clean; shopt -s extdebug; skip; assert_raises false; shopt extdebug"

assert_end interaction

# commit: fixed output to report all errors, not just the first
assert "_clean;
assert_raises false; assert_raises false;
assert_end" 'test #1 "false" failed:
\tprogram terminated with code 1 instead of 0
test #2 "false" failed:
\tprogram terminated with code 1 instead of 0
2 of 2 tests failed.'
# commit: added default value for assert_raises
assert_raises "_clean; assert_raises true; assert_end" 0
# commit: fixed verbose failure reports in assert_raises
assert "_clean DEBUG=1; assert_raises false; assert_end" 'X
test #1 "false" failed:
\tprogram terminated with code 1 instead of 0
1 of 1 tests failed.'
# commit: redirected assert_raises output
assert "_clean; assert_raises 'echo 1'; assert_end" "all 1 tests passed."
# commit: fixed --discover to reset properly
assert "_clean DISCOVERONLY=1;
assert 1; assert 1; assert_end;
assert 1; assert_end;" "collected 2 tests.\ncollected 1 tests."
# commit: stopped errors from leaking into other test suites
assert "_clean;
assert_raises false; assert_raises false; assert_end;
assert_raises false; assert_end" 'test #1 "false" failed:
\tprogram terminated with code 1 instead of 0
test #2 "false" failed:
\tprogram terminated with code 1 instead of 0
2 of 2 tests failed.
test #1 "false" failed:
\tprogram terminated with code 1 instead of 0
1 of 1 tests failed.'
# issue 1: assert.sh: line 87: DISCOVERONLY: unbound variable
assert "_clean; set -u; assert_raises true; assert true; assert_end" \
"all 2 tests passed."
# issue 3: Not working on Mac OS X 10.7.5
assert "
_date=20;
date() {
echo \${_date}N;
};
_clean INVARIANT=;
assert date 20N;
_date=22;
assert_end" "all 1 tests passed in 2.000s."
# commit: supported formatting codes
assert "echo %s" "%s"
# We trim the output from wc as the BSD version (on Mac OS) contains leading spaces
assert "echo -n %s | wc -c | tr -d '[[:space:]]'" "2"
# date with no nanosecond support
date() {         # date mock
    echo "123N"
}
assert '_clean DEBUG=1 INVARIANT=; tests_starttime="0N"; assert_end' \
       '\nall 0 tests passed in 123.000s.'
unset -f date  # bring back original date
# commit: Supporting multiline inputs
# We trim the output from wc as the BSD version (on Mac OS) contains leading spaces
assert 'echo "this
is a multiline echo" | wc -l | tr -d "[[:space:]]"' "2"
assert 'echo -e "this\nis a multiline echo" | wc -l | tr -d "[[:space:]]"' "2"
assert_end regression



### assert-extras.sh


assert "echo foo" "foo"
assert_raises "true" 0
assert_raises "exit 127" 127

assert_end sanity

###
### assert_success tests
###

# Tests expecting success
assert_success "true"
assert_success "echo foo"
assert_success "cat" "foo"

# Tests expecting failure
assert_raises 'assert_success "false"' 1
assert_raises 'assert_success "exit 1"' 1

assert_end assert_success

###
### assert_failure tests
###

# Tests expecting success
assert_failure "false"
assert_failure "exit 1"
assert_failure "exit -1"
assert_failure "exit 42"
assert_failure "exit -42"

# Tests expecting failure
assert_raises 'assert_failure "true"' 1
assert_raises 'assert_failure "echo foo"' 1

assert_end assert_failure

###
### assert_contains tests
###

# Tests expecting success
assert_contains "echo foo" "foo"
assert_contains "echo foobar" "foo"
assert_contains "echo foo bar" "foo"
assert_contains "echo foo bar" "bar"
assert_contains "echo foo bar" "foo bar"

# Tests expecting failure
assert_failure 'assert_contains "echo foo" "foot"'
assert_failure 'assert_contains "echo foo" "f.."'

# Multi-word argument tests
assert_contains "echo foo bar" "foo bar"
assert_failure 'assert_contains "echo foo; echo bar" "foo bar"'

# Multi-argument tests
assert_contains "echo foo bar baz" "foo" "baz"
assert_failure 'assert_contains "echo foo bar baz" "bar" "foo baz"'

assert_end assert_contains

###
### assert_matches tests
###

# Tests expecting success
assert_matches "echo foo" "f.."
assert_matches "echo foobar" "f."
assert_matches "echo foo bar" "^foo bar$"
assert_matches "echo foo bar" "[az ]+"

# Tests expecting failure
assert_failure 'assert_matches "echo foot" "foo$"'

# Multi-word argument tests
assert_matches "echo foo bar" "foo .*"
assert_failure 'assert_matches "echo foo; echo bar" "foo .*"'

# Multi-argument tests
assert_matches "echo foo bar baz" "^f.." "baz$"
assert_failure 'assert_matches "echo foo bar baz" "bar" "foo baz"'

assert_end assert_matches

###
### assert_startswith tests
###

# Tests expecting success
assert_startswith "echo foo" "f"
assert_startswith "echo foo" "foo"
assert_startswith "echo foo; echo bar" "foo"

# Tests expecting failure
assert_failure 'assert_startswith "echo foo" "oo"'
assert_failure 'assert_startswith "echo foo; echo bar" "foo bar"'
assert_failure 'assert_startswith "echo foo" "."'

assert_end assert_startswith

###
### assert_endswith tests
###

# Tests expecting success
assert_endswith "echo foo" "oo"
assert_endswith "echo foo" "foo"
assert_endswith "echo foo; echo bar" "bar"

# Tests expecting failure
assert_failure 'assert_endswith "echo foo" "f"'
assert_failure 'assert_endswith "echo foo; echo bar" "foo bar"'
assert_failure 'assert_endswith "echo foo" "."'

assert_end assert_endswith
