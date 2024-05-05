:
# https://github.github.com/gfm/#example-588

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
My ![foo bar](/path/to/train.jpg  "title"   )
EOF

cat >$EXPECT <<EOF
<p>My <img src="/path/to/train.jpg" alt="foo bar" title="title" /></p>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
