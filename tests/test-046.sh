:
# https://github.github.com/gfm/#example-46

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
### foo \\###
## foo #\\##
# foo \\#
EOF

cat >$EXPECT <<EOF
<h3>foo ###</h3>
<h2>foo ###</h2>
<h1>foo #</h1>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
