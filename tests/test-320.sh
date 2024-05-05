:
# https://github.github.com/gfm/#example-320

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
\`\`\` foo\\+bar
foo
\`\`\`
EOF

cat >$EXPECT <<EOF
<pre><code class="language-foo+bar">foo
</code></pre>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
