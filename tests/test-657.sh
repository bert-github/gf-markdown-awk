:
# https://github.github.com/gfm/#example-657
# Modified: both "<" and ">" escaped, rather than only "<".

trap 'rm -f $IN $EXPECT $OUT' 0
IN=`mktemp /tmp/test-XXXXXX`
EXPECT=`mktemp /tmp/test-XXXXXX`
OUT=`mktemp /tmp/test-XXXXXX`

cat >$IN <<EOF
<strong> <title> <style> <em>

<blockquote>
  <xmp> is disallowed.  <XMP> is also disallowed.
</blockquote>
EOF

cat >$EXPECT <<EOF
<p><strong> &lt;title&gt; &lt;style&gt; <em></p>
<blockquote>
  &lt;xmp&gt; is disallowed.  &lt;XMP&gt; is also disallowed.
</blockquote>
EOF

gawk '@include "markdown.awk"; { lines = lines $0 "\n" } END { printf "%s", markdown::to_html(lines) }' $IN >$OUT

diff -u $EXPECT $OUT
