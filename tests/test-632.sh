:
# https://github.github.com/gfm/#example-632

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
a.b-c_d@a.b

a.b-c_d@a.b.

a.b-c_d@a.b-

a.b-c_d@a.b_
EOF

cat >$EXPECT <<EOF
<p><a href="mailto:a.b-c_d@a.b">a.b-c_d@a.b</a></p>
<p><a href="mailto:a.b-c_d@a.b">a.b-c_d@a.b</a>.</p>
<p>a.b-c_d@a.b-</p>
<p>a.b-c_d@a.b_</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
