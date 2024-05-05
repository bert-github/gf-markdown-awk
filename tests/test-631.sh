:
# https://github.github.com/gfm/#example-631

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
hello@mail+xyz.example isn't valid, but hello+xyz@mail.example is.
EOF

cat >$EXPECT <<EOF
<p>hello@mail+xyz.example isn't valid, but <a href="mailto:hello+xyz@mail.example">hello+xyz@mail.example</a> is.</p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
