:
# https://github.github.com/gfm/#example-250

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
    indented code

paragraph

    more code
EOF

cat >$EXPECT <<EOF
<pre><code>indented code
</code></pre>
<p>paragraph</p>
<pre><code>more code
</code></pre>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
