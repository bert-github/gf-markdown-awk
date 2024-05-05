:
# https://github.github.com/gfm/#example-585

exit 2				# Not applicable

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
![foo *bar*][]

[foo *bar*]: train.jpg "train & tracks"
EOF

cat >$EXPECT <<EOF
<p><img src="train.jpg" alt="foo bar" title="train &amp; tracks" /></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
