:
# https://github.github.com/gfm/#example-101

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
 \`\`\`
 aaa
aaa
\`\`\`
EOF

cat >$EXPECT <<EOF
<pre><code>aaa
aaa
</code></pre>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
