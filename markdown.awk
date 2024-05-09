# Library for converting GitHub-flavored markdown to HTML.
#
# Works with Gnu Awk. Here is an example of how to use this library to
# create a program that converts markdown to HTML:
#
#     @include "markdown.awk"
#     { lines = lines $0 "\n" }
#     END { printf "%s", markdown::to_html(lines) }
#
#
# More documentation:
#
# To use the library, put
#
#     @include "markdown.awk"
#
# in your Awk program. That makes the following functions available:
#
# markdown::to_html(string)
#
#     This function is given a string with markdown text and returns
#     an HTML fragment. It does not return a complete HTML document:
#     The returned fragment is meant to be put in the BODY of an HTML
#     document.
#
#     Example:
#
#        print markdown::to_html("### Heading 3\nPara 1")
#
#     yields
#
#        <h3>Heading 3</h3>
#        <p>Para 1</p>
#
# markdown::to_inline_html(string)
#
#     This function is given a string with markdown text and returns
#     an HTML fragment with only inline HTML. If the string contains
#     markdown for block elements, those are not interpreted and
#     treated as text.
#
#     Example:
#
#        print markdown::to_inline_html("Text with *emphasized words.*")
#
#     yields
#
#        Text with <em>emphasized words.</em>
#
# markdown::to_text(string)
#
#     This function is given a string with markdown text and returns
#     plain text with just the text content, after removing all
#     markup. The result is a plain text string, not an HTML string,
#     i.e., it may contain '<', '>', '&' and '"' characters which are
#     not escaped as HTML character entities. '&lt;', etc.
#
#     Example:
#
#        print markdown:to_text("### An *emphasized* heading")
#
#     yields
#
#        An emphasized heading
#
# markdown::html_to_text(string)
#
#     This function is given HTML and returns the text content,
#     stripped of all tags. For images, the alt text is returned. For
#     all other elements, the text content is returned.
#
# markdown::version()
#
#     Returns the version of this library, currently "0.2".
#
#
# Copyright © 2023-2024 World Wide Web Consortium.
# See the file COPYING.
#
# Created: 28 May 2023
# Author: Bert Bos <bert@w3.org>

@include "htmlmathml.awk"

@namespace "markdown"


# version -- return the version number of this library
function version()
{
  return "0.2"
}


# to_html -- markdown to HTML
function to_html(s,	n, i, lines, stack, curblock, result)
{
  # Parse the markdown line by line.
  #
  sub(/\n$/, "", s)
  n = split(s, lines, /\n/)
  for (i = 1; i <= n; i++) {
    # printf "Next line: \"%s\"\n", lines[i] > "/dev/stderr"
    add_line_to_tree(stack, 1, expand_tabs(lines[i]), curblock, result)
  }
  close_blocks(stack, 1, curblock, result)
  return join(result)
}


# to_inline_html -- convert markdown to inline HTML
function to_inline_html(s,		replacements)
{
  return expand(inline(s, 0, replacements), replacements)
}


function expand(s, replacements,		t, n, x, i)
{
  # Replace the <n> tags in s by the corresponding code that was
  # stored in replacements. The replacements may themselves contain
  # further tags, so repeat until there are no more changes (n == 0).
  do {
    t = ""
    n = 0
    while ((i = match(s, /\002([0-9]+)\003/, x))) {
      # print "retrieve replacement " x[1] " -> " item(replacements, 0 + x[1]) > "/dev/stderr"
      t = t substr(s, 1, i - 1) item(replacements, 0 + x[1])
      s = substr(s, i + length(x[0]))
      n++
    }
    s = t s
  } while (n)

  return s
}


# inline -- parse inline markdown and return HTML code
function inline(s, no_links, replacements,		result, t, i, x)
{
  # no_links: if 1, links (<a> elements) are not allowed and will be
  # converted to text.
  #
  # replacements: an array of HTML fragments. When markdown is being
  # replaced by HTML code, the HTML code is stored in this array and a
  # marker is put in the markdown text. The to_inline_html() function
  # will eventually replace each marker by the HTML code it refers to,
  # to construct the final HTML text.

  # Replace occurrences in s of code spans (`...`), autolinks (<url>),
  # HTML tags (elements, comments, CDATA sections, processing
  # instructions), links ("[...](...)") and images ("![...](...)") by
  # "<n>" tags.
  #
  # Put the corresponding HTML code in replacements at index n. The
  # "<n>" tags actually consist of \002 + decimal number + \003.
  #
  # t = what we parsed so far, s = the string yet to parse.
  #
  t = ""
  while ((i = match(s, /`+|<|!?\[/, x)))
    if (is_escaped(s, i)) {	# After a backslash. Skip one character
      t = t substr(s, 1, i)
      s = substr(s, i + 1)
    } else if (inline_code_span(s, i, replacements, result) ||
	       inline_autolink(s, i, no_links, replacements, result) ||
	       inline_html_tag(s, i, replacements, result) ||
	       inline_link_or_image(s, i, no_links, replacements, result)) {
      t = t substr(s, 1, i - 1) result["html"]
      s = result["rest"]
    } else {			# Apparently not a delimiter, take it literally
      t = t substr(s, 1, i - 1) "\002" push(replacements, esc_html(x[0])) "\003"
      s = substr(s, i + length(x[0]))
    }
  s = t s

  # Replace occurences of bold and italic emphasis (*...*, **...**,
  # ***...***, _..._, __...__ or ___...___).
  #
  t = ""
  while ((i = match(s, /\*+|_+/, x)))
    if (is_escaped(s, i)) {	# After a backslash. Skip one character
      t = t substr(s, 1, i)
      s = substr(s, i + 1)
    } else if (inline_emphasis(s, i, no_links, replacements, result)) {
      t = t substr(s, 1, i - 1) result["html"]
      s = result["rest"]
    } else {			# Apparently not an opening delimiter, skip it
      t = t substr(s, 1, i - 1) "\002" push(replacements, x[0]) "\003"
      s = substr(s, i + length(x[0]))
    }
  s = t s

  # Replace occurrences in s of strikethrough (~...~, ~~...~~).
  #
  t = ""
  while ((i = match(s, /~+/, x)))
    if (is_escaped(s, i)) {	# After a backslash. Skip one character
      t = t substr(s, 1, i)
      s = substr(s, i + 1)
    } else if (inline_strikethrough(s, i, no_links, replacements, result)) {
      t = t substr(s, 1, i - 1) result["html"]
      s = result["rest"]
    } else {			# Apparently not a valid delimiter. Skip it.
      t = t substr(s, 1, i - 1) "\002" push(replacements, x[0]) "\003"
      s = substr(s, i + length(x[0]))
    }
  s = t s

  # Replace hard line breaks by <br> and remove backslash escapes.
  #
  t = "\002" push(replacements, "<br />\n") "\003"
  s = awk::gensub(/ \n/, "\n", "g",
    awk::gensub(/(  +|\\)\n/, t, "g", esc_html(unesc_md(s))))

  return s
}


# inline_code_span -- try to parse markdown starting at i in s as code span (`...`)
function inline_code_span(s, i, replacements, result,
			  x, j, content, n, t)
{
  # s: the markdown string to parse.
  #
  # i: the index in s where to start parsing.
  #
  # replacements: a stack to hold generared HTML code fragments
  # (passed by reference).
  #
  # result: an array with two entries, result["html"] and
  # result["rest"], in which the function returns, respectively, the
  # result of parsing the code span and the rest of the text of s
  # after the parsed code span.
  #
  # Returns 1 for success, 0 for failure.

  # print "inline_code_span(\"" s "\", " i ")" > "/dev/stderr"

  # Check that the first "`" is not escaped with a backslash.
  if (is_escaped(s, i)) return 0

  # Check that that text at index i in s starts with a span of "`".
  if (! match(substr(s, i), /^(`+)(.*)/, x)) return 0

  # Check that there is another span of "`" of equal length.
  if (! (j = match(x[2], "[^`]" x[1] "([^`]|$)"))) return 0

  # Replace newlines in the contents by spaces.
  content = awk::gensub(/\n/, " ", "g", substr(x[2], 1, j))

  # If there is a space both at the start and at the end, and at least
  # one non-space in between, remove the two spaces at start and end.
  if (content ~ /^ .*[^ ].* $/) content = substr(content, 2, j - 2)

  # Store HTML code in replacements.
  t = "<code>" esc_html(content) "</code>"
  n = push(replacements, t)

  # Return result.
  result["html"] = "\002" n "\003"
  result["rest"] = substr(x[2], j + length(x[1]) + 1)
  # print "Found inline code <" n "> = " t > "/dev/stderr"
  return 1
}


# inline_autolink -- try to parse text starting at i in s as an autolink
function inline_autolink(s, i, no_links, replacements, result,
			 x, t, n)
{
  # s: the markdown text to parse
  #
  # i: where in s to start parsing
  #
  # no_links: whether links should be rendered as text rather than <a>
  # elements.
  #
  # replacements: a stack of HTML fragments. (Passed by reference.)
  #
  # result: an array in which the function returns the result of
  # parsing the autolink and the remaining text of s after the
  # autolink.
  #
  # Returns 1 for success, 0 for failure.

  # Check that the "<" is not escaped with a backslash.
  if (is_escaped(s, i)) return 0

  # print "inline_autolink(\"" s "\", " i ")" > "/dev/stderr"

  # Set s to the text to parse.
  s = substr(s, i)

  if (match(s, /^<([a-zA-Z][a-zA-Z0-0+.-]+:[^>[:space:]]+)>/, x)) {
    # A URL

    if (no_links) t = esc_html(x[1])
    else t = "<a href=\"" esc_html(esc_url(x[1])) "\">" esc_html(x[1]) "</a>"

  } else if (match(s, /^<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>/, x)) {
    # An email address

    if (no_links) t = esc_html(x[1])
    else t = "<a href=\"mailto:" esc_html(x[1]) "\">" esc_html(x[1]) "</a>"

  } else {			# Neither URL nor email address

    return 0
  }

  n = push(replacements, t) # Store the HTML code in replacements, get its index
  result["html"] = "\002" n "\003" # The tag to replace the auutolink with
  result["rest"] = substr(s, length(x[0]) + 1)
  # print "Found autolink <" n "> = " t > "/dev/stderr"
  return 1
}


# inline_html_tag -- try to parse text at index i in s as an HTML tag
function inline_html_tag(s, i, replacements, result,
			 x, t, n)
{
  # s: the markdown text to parse.
  #
  # i: where in s to start parsing.
  #
  # replacements: a stack of HTML fragments. (Passed by reference.)
  #
  # result: an array in which the function returns the result of
  # parsing the HTML tag and the remaining text of s after the
  # tag.
  #
  # Returns 1 for success, 0 for failure.

  # Check that the "<" is not escaped with a backslash.
  assert(! is_escaped(s, i), "! is_escaped(s, i)")

  # print "inline_html_tag(\"" s "\",...)" > "/dev/stderr"

  # Set s to the text to parse.
  s = substr(s, i)

  if (((match(s, /^<([a-zA-Z][a-zA-Z0-9_-]*)(\s+[a-zA-Z0-9:_][a-zA-Z0-9_.:-]*(\s*=\s*([^[:space:]"'=<>`]+|"[^"]*"|'[^']*'))?)*\s*\/?>/, x) ||
	match(s, /^<\/([a-zA-Z][a-zA-Z0-9_-]*)\s*>/, x)) &&
       tolower(x[1]) !~ /^(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)$/) ||
      match(s, /^<!\[CDATA\[([^\]]|\][^\]]|\]\][^>])*\]\]>/, x) ||
      match(s, /^<!--([^->]|-[^->])*-->/, x) ||
      match(s, /^<![a-zA-Z][^>]*>/, x) ||
      match(s, /^<\?([^?>]|\?[^>])*\?>/, x)) {
    t = x[0]			# Copy the tag verbatim
    n = push(replacements, t) # # Store HTML code in replacements, get its index
    result["html"] = "\002" n "\003"	# The tag to replace the auutolink with
    result["rest"] = substr(s, length(x[0]) + 1)
    # print "Found HTML tag <" n "> = " t > "/dev/stderr"
    return 1
  }
  return 0
}


#  inline_link_or_image -- try to parse text at index i in s as a link or image
function inline_link_or_image(s, i, no_links, replacements, result,
			      x, t, u, n, j, is_image, url, title, result1)
{
  # s: the markdown text to parse.
  #
  # i: where in s to start parsing.
  #
  # no_links: whether links should be rendered as text rather than <a>
  # elements.
  #
  # replacements: a stack of HTML fragments. (Passed by reference.)
  #
  # result: an array in which the function returns the result of
  # parsing the link and the remaining text of s after the
  # autolink.
  #
  # Returns 1 for success, 0 for failure.

  # print "inline_link_or_image(\"" s "\", " i ", " no_links ",...)" > "/dev/stderr"

  # Check that the "<" is not escaped with a backslash.
  if (is_escaped(s, i)) return 0

  # Set s to the text to parse.
  s = substr(s, i)

  # Check that the text starts with "![" or "[".
  if (s ~ /^!\[/) { is_image = 1; s = substr(s, 3) }
  else if (s ~ /^\[/) { is_image = 0; s = substr(s, 2) }
  else return 0

  # Collect in t all the text between the initial "[" and the matching
  # "]" (the anchor text), while allowing matching bracket pairs and
  # backslash-escaped brackets to occur between the two. Set s to the
  # string starting with the matching "]".
  t = ""
  n = 0
  while ((j = match(s, /`+|<|!?\[|\]/, x)))
    if (is_escaped(s, j)) {
      t = t substr(s, 1, j); s = substr(s, j + 1)
    } else if (x[0] ~ /^[`<]/) {
      if (inline_code_span(s, j, replacements, result1) ||
	  inline_autolink(s, j, no_links, replacements, result1) ||
	  inline_html_tag(s, j, replacements, result1)) {
	t = t substr(s, 1, j - 1) result1["html"]; s = result1["rest"]
      } else {			# delimiter that does not start anything
	t = t substr(s, 1, i-1) "\002" push(replacements, esc_html(x[0])) "\003"
	s = substr(s, i + length(x[0]))
      }
    } else if (x[0] == "![") {
      if (inline_link_or_image(s, j, no_links || is_image, replacements,
			       result1)) {
	t = t substr(s, 1, j - 1) result1["html"]; s = result1["rest"]
      } else {			# delimiter that does not start anything
	n++
	t = t substr(s, 1, i-1) "\002" push(replacements, esc_html(x[0])) "\003"
	s = substr(s, i + length(x[0]))
      }
    } else if (x[0] == "[") {
      if (! is_image) {		# We're inside a link "[...](...)"
	if (inline_link_or_image(s, j)) {
	  return 0
	} else {		# "[" that does not start a link
	  n++; t = t substr(s, i, j); s = substr(s, j + 1)
	}
      } else {			# We're inside an image "![...](...)"
	if (inline_link_or_image(s, j, 1, replacements, result1)) {
	  t = t substr(s, 1, j - 1) result1["html"]; s = result1["rest"]
	} else {		# "[" that does not start a link
	  n++; t = t substr(s, i, j); s = substr(s, j + 1)
	}
      }
    } else if (n != 0) {	# Balanced "]"
      n--; t = t substr(s, i, j); s = substr(s, j + 1)
    } else {			# "]" that ends the anchor/alt text
      t = t substr(s, 1, j - 1); s = substr(s, j); break
    }
  # print "anchor = \"" t "\" rest=\"" s "\"" > "/dev/stderr"

  # If s does not start with "](", this is not a link.
  if (! match(s, /^\]\(\s*/, x)) return 0
  s = substr(s, length(x[0]) + 1)

  # Get the URL: <...> or text with balanced ().
  url = ""
  if (match(s, /^</)) {
    s = substr(s, 2)
    while ((j = match(s, /[\n>]/, x)))
      if (x[0] == "\n") {
	return 0		# Newline not allowed between < and >
      } else if (is_escaped(s, j)) {
	url = url substr(s, 1, j); s = substr(s, j + 1)
      } else {
	url = url substr(s, 1, j - 1); s = substr(s, j); break
      }
    if (s !~ /^>/) return 0
    s = substr(s, 2)
  } else {			# Text that does not start with "<"
    n = 0
    while ((j = match(s, /[()\000\001\004- ]/, x)))
      if ((x[0] == "(" || x[0] == ")") && is_escaped(s, j)) {
	url = url substr(s, 1, j); s = substr(s, j + 1)
      } else if (x[0] == "(") {
	n++; url = url substr(s, 1, j); s = substr(s, j + 1)
      } else if (x[0] != ")") {
	url = url substr(s, 1, j - 1); s = substr(s, j); break
      } else if (n != 0) {	# balanced ")"
	n--; url = url substr(s, 1, j); s = substr(s, j + 1)
      } else {			# unbalanced ")"
	url = url substr(s, 1, j - 1); s = substr(s, j); break
      }
  }
  # print "Found URL=\"" url "\" rest=\"" s "\"" > "/dev/stderr"

  # Get the optional title and the final ")".
  if (! match(s, /^([ \t\n\v\f\r]+"(([^"]|\\")*)"|[ \t\n\v\f\r]+'(([^']|\\')*)'|[ \t\n\v\f\r]+\((([^\)]|\\[()])*)\))?[ \t\n\v\f\r]*\)/, x)) return 0
  #                1               23        3 2                 45        5 4                  67            7 6  1
  title = x[2] x[4] x[6]
  s = substr(s, length(x[0]) + 1)
  # print "Found title: \"" title "\" rest=\"" s "\"" > "/dev/stderr"

  # Convert the anchor text t to HTML. The 1 indicates that no links
  # are allowed in that text.
  t = inline(t, 1, replacements)
  # print "parsed anchor = \"" t "\"" > "/dev/stderr"

  # Create the HTML code for the link or image.
  if (no_links) {	     # Nested links not allowed, use text only
    u = t
  } else if (is_image) {
    u = "<img src=\"" esc_html(esc_url(unesc_md(url))) "\""	\
      " alt=\"" esc_html(html_to_text(expand(t, replacements))) "\""
    if (title) u = u " title=\"" esc_html(unesc_md(title)) "\""
    u = u " />"
  } else {
    u = "<a href=\"" esc_html(esc_url(unesc_md(url))) "\""
    if (title) u = u " title=\"" esc_html(unesc_md(title)) "\""
    u = u ">" t "</a>"
  }

  # Store the HTML code in replacements at index n and return a tag
  # "<n>".
  result["html"] = "\002" push(replacements, u) "\003"
  result["rest"] = s
  # print "\"" u "\" -> " size(replacements) > "/dev/stderr"
  return 1
}


# inline_emphasis -- try to parse text at index i in s as emphasis
function inline_emphasis(s, i, no_links, replacements, result,
			 x, t, u, j, n, closing, closinglen, len, delim,
			 is_left_fn, is_right_fn, result1)
{
  # s: the markdown text to parse.
  #
  # i: where in s to start parsing.
  #
  # no_links: whether nested links should be rendered as text rather
  # than <a> elements.
  #
  # replacements: a stack of HTML fragments. (Passed by reference.)
  #
  # result: an array in which the function returns the result of
  # parsing the emphasis span and the remaining text of s after the
  # span.
  #
  # Returns 1 for success, 0 for failure.

  assert(substr(s, i, 1) ~ /[*_]/, "substr(s, i, 1) ~ /[*_]/")

  # print "inline_emphasis(\"" s "\", " i ",...)" > "/dev/stderr"

  # Slightly different rules for "*" and "_": use is_left_flanking()
  # for "*" and is_left_flanking_plus() for "_".
  #
  delim = substr(s, i, 1) == "_" ? "_" : "\\*"
  if (delim == "_") {
    is_left_fn = "markdown::is_left_flanking_plus"
    is_right_fn = "markdown::is_right_flanking_plus"
  } else {
    is_left_fn = "markdown::is_left_flanking"
    is_right_fn = "markdown::is_right_flanking"
  }

  # Check that this run of delimiters is a valid opening delimiter.
  match(substr(s, i), delim "+")
  if (! @is_left_fn(s, i, RLENGTH)) return 0

  # Loop until all delimiters in the opening run have been consumed,
  # i.e., matched by a closing delimiter.
  s = substr(s, i)			# The text to parse
  match(s, "^(" delim "+)(.*)", x)	# x[1] = opening delim, x[2] = rest
  result["html"] = x[1]			# The current results
  result["rest"] = x[2]			# The unprocessed rest

  while (x[1] != "") {

    # print "x[1]=\"" x[1] " x[2]=\"" x[2] "\"" > "/dev/stderr"

    # Find a potential closing delimiter.
    # TODO: Apply rule 10 which says that "*foo**bar*" is
    # "<em>foo**bar</em>" rather than "is "<em>foo</em<em>bar</em>".
    # (https://github.github.com/gfm/#emphasis-and-strong-emphasis)
    u = x[2]
    j = 1
    while (1) {
      if (! match(u, delim "+")) { j = 0; break }
      j += RSTART - 1; len = RLENGTH
      # print "found a * at j=" j ", len=" len ", is_right_flanking->" @is_right_fn(x[2], j, len) " is_escaped->" is_escaped(x[2], j) > "/dev/stderr"
      if (is_escaped(x[2], j)) u = substr(x[2], ++j)
      else if (@is_right_fn(x[2], j, len)) break
      else { j += len; u = substr(x[2], j) }	# Try again after the match
    }

    # If we found no closing delimiter, stop the loop.
    if (j == 0) break

    closing = j
    closinglen = len
    # print "closing=" closing > "/dev/stderr"

    # Find if there is an opening delimiter earlier than the closing
    # delimiter we found. If so, we have to treat that one first. The
    # closing delimiter might belong to that.
    u = x[2]
    j = 1
    while (1) {
      if (! match(u, delim "+")) { j = 0; break }
      j += RSTART - 1; len = RLENGTH
      if (j >= closing) { j = 0; break }
      if (is_escaped(x[2], j)) u = substr(x[2], ++j)
      else if (inline_emphasis(x[2], j, no_links, replacements, result1)) break
      else { j += len; u = substr(x[2], j) }	# Try again after the match
    }
    # print "j=" j > "/dev/stderr"

    if (j != 0) {
      # We found and processed an opening delimiter. Replace the
      # processed part in the string s by the result of processing.
      t = "\002" push(replacements, result1["html"]) "\003"
      result["html"] = x[1] substr(x[2], 1, j - 1) t
      result["rest"] = result1["rest"]
      s = result["html"] result["rest"]
      match(s, "^(" delim "+)(.*)", x)

    } else {
      # There is no opening delimiter before the closing delimiter we
      # found, so the closing delimiter can be used to match the
      # delimiter we are trying to process.
      #
      # Compute the replacement for the text between the opening and
      # closing delimiters.
      t = inline(substr(x[2], 1, closing - 1), no_links, replacements)
      # print "processed \"" substr(x[2], 1, closing - 1) "\" -> \"" t "\"" > "/dev/stderr"

      # Enclose the replacement in <strong> and/or <em>, depending on
      # how many *'s were matched (= n).
      n = min(length(x[1]), closinglen)
      for (j = n; j > 1; j -= 2) {
	t = "\002" push(replacements, "<strong>") "\003" t
	t = t "\002" push(replacements, "</strong>") "\003"
      }
      if (n % 2 == 1) {
	t = "\002" push(replacements, "<em>") "\003" t
	t = t "\002" push(replacements, "</em>") "\003"
      }

      # The result so far consists of any remaining part of the
      # opening delimiter, and the replacement just computed.
      result["html"] = substr(x[1], 1, length(x[1]) - n) t
      result["rest"] = substr(x[2], closing + n)

      # Replace the processed part of the string s (the matched
      # opening and closing delimiters and the text in between) by the
      # result of processing (= t). Restart the loop to process the
      # remaining part of the opening delimiter. (There may not be any
      # left).
      s = result["html"] result["rest"]
      match(s, "^(" delim "+)(.*)", x)
    }
  }
  return 1
}


# inline_strikethrough -- try to parse text at index i in s as deletion (~...~)
function inline_strikethrough(s, i, no_links, replacements, result,
			      x, j, t)
{
  # s: the markdown text to parse.
  #
  # i: where in s to start parsing.
  #
  # no_links: whether nested links should be rendered as text rather
  # than <a> elements.
  #
  # replacements: a stack of HTML fragments. (Passed by reference.)
  #
  # result: an array in which the function returns the result of
  # parsing the span and the remaining text of s after the span.
  #
  # Returns 1 for success, 0 for failure.

  assert(substr(s, i, 1) == "~", "substr(s, i, 1) == \"~\"")

  # Check that there is no uneven number of backslashes before the ~
  if (is_escaped(s, i)) return 0

  # Check that we have either 1 or 2 ~'s.
  match(substr(s, i), /^(~+)(.*)/, x)
  if (length(x[1]) > 2) return 0

  # Set s to the string to parse.
  s = x[2]

  # Find a matching closing delimiter.
  t = s
  j = 0
  while (1) {
    if (! match(t, x[1])) {j = 0; break }
    j += RSTART; t = substr(t, RSTART + RLENGTH)
    if (is_escaped(s, j)) { j++; t = substr(t, 2) }
    else if (t !~ /^~/) break	# Not followed by another ~: Success
  }

  # If we found no closing delimiter, return failure.
  if (j == 0) return 0

  # Process the text between the two delimiters and enclose the result
  # in <del> and </del>.
  t = inline(substr(s, 1, j - 1), no_links, replacements)
  t = "\002" push(replacements, "<del>") "\003" t
  t = t "\002" push(replacements, "</del>") "\003"

  result["html"] = t
  result["rest"] = substr(s, j + length(x[1]))
  return 1
}


# is_left_flanking -- check if the delimiter run at i in s is left-flanking
function is_left_flanking(s, i, len,	before, after, r)
{
  # Preceded by an even number of backslashes (including 0) and is a
  # left-flanking delimiter run.
  #
  # A left-flanking delimiter run is a delimiter run that is (1) not
  # followed by Unicode whitespace, and either (2a) not followed by a
  # punctuation character, or (2b) followed by a punctuation character
  # and preceded by Unicode whitespace or a punctuation character. For
  # purposes of this definition, the beginning and the end of the line
  # count as Unicode whitespace.
  before = substr(s, 1, i - 1)
  after = substr(s, i + len)
  r = match(before, /\\*$/) && RLENGTH % 2 == 0 &&
    after ~ /^[^[:space:]]/ &&
    (after ~ /^[^[:punct:]]/ ||
     (after ~ /^[[:punct:]]/ && before ~ /(^|[[:space:][:punct:]])$/))
  # print "is_left_flanking(\"" s "\", " i ", " len ") -> " r > "/dev/stderr"
  return r
}


# is_left_flanking_plus -- check if the delimiters at i in s can start emphasis
function is_left_flanking_plus(s, i, len,		r)
{
  # Part of a left-flanking delimiter run and either (a) not part of a
  # right-flanking delimiter run or (b) part of a right-flanking
  # delimiter run preceded by punctuation.

  r = is_left_flanking(s, i, len) &&
    (! is_right_flanking(s, i, len) || substr(s, 1, i - 1) ~ /[[:punct:]]$/)
  # print "is_left_flanking_plus(\"" s "\", " i ", " len ") -> " r > "/dev/stderr"
  return r
}


# is_right_flanking -- check if the delimiter run at i in s is right-flanking
function is_right_flanking(s, i, len,		before, after, r)
{
  # Preceded by an even number of backslashes (including 0) and is a
  # right-flanking delimiter run.
  #
  # A right-flanking delimiter run is a delimiter run that is (1) not
  # preceded by Unicode whitespace, and either (2a) not preceded by a
  # punctuation character, or (2b) preceded by a punctuation character
  # and followed by Unicode whitespace or a punctuation character. For
  # purposes of this definition, the beginning and the end of the line
  # count as Unicode whitespace.
  before = substr(s, 1, i - 1)
  after = substr(s, i + len)
  r = match(before, /\\*$/) && RLENGTH % 2 == 0 &&
    before ~ /[^[:space:]]$/ &&
    (before ~ /[^[:punct:]]$/ ||
     (before ~ /[[:punct:]]$/ && after ~ /^([[:space:][:punct:]]|$)/))
  # print "is_right_flanking(\"" s "\", " i ", " len ") -> " r > "/dev/stderr"
  return r
}


# is_right_flanking_plus -- check if the delimiters at i in s can end emphasis
function is_right_flanking_plus(s, i, len,	r)
{
  # Check if the delimiter run at index i in s is part of a
  # right-flanking delimiter run and either (a) not part of a
  # left-flanking delimiter run or (b) part of a left-flanking
  # delimiter run followed by punctuation.
  #
  r = is_right_flanking(s, i, len) &&
    (! is_left_flanking(s, i, len) || substr(s, i + len) ~ /^[[:punct:]]/)
  # print "is_right_flanking_plus(\"" s "\", " i ", " len ") -> " r > "/dev/stderr"
  return r
}


# is_escaped - check if character i in s is preceded by an uneven number of "\"
function is_escaped(s, i)
{
  return match(substr(s, 1, i - 1), /\\+$/) && RLENGTH % 2 == 1
}


# min -- return the smallest of two values
function min(a, b)
{
  return a < b ? a : b
}


# to_text -- remove markdown
function to_text(s)
{
  # First convert the markdown to HTML and then remove all HTML tags,
  # replace HTML entities and remove the final newline. (Internal
  # newlines remain.) The function to_html() already replaced all
  # character entities other than "&lt;", "&gt;", "&quot;" and
  # "&amp;".
  #
  return html_to_text(to_html(s))
}


# html_to_text -- return only the text content of HTML
function html_to_text(t)
{
  # Remove comments.
  gsub(/^<!--([^->]|-[^->])*-->/, "", t)

  # Replace images by their alt text.
  t = awk::gensub(/<img\>[^>]*\<alt="([^"]*)"[^>]*>/, "\\1", "g", t)
  t = awk::gensub(/<img\>[^>]*\<alt='([^']*)'[^>]*>/, "\\1", "g", t)

  # Remove all other tags.
  gsub(/<[^>]*>/, "", t)

  # Replace remaining entities.
  gsub(/&quot;/, "\"", t)
  gsub(/&gt;/, ">", t)
  gsub(/&lt;/, "<", t)
  gsub(/&amp;/, "\\&", t)

  # Remove final newline.
  gsub(/\n$/, "", t)
  # print "html_to_text(\"" s "\") -> \"" t "\"" > "/dev/stderr"
  return t
}


# expand_tabs - replace tabs by the right number of spaces
function expand_tabs(line,	result, col, c)
{
  # This is wrong, tabs are not supposed to be replaced by spaces,
  # except at the start of a line.

  result = ""
  col = 1
  while (line != "") {
    c = substr(line, 1, 1)
    line = substr(line, 2)
    if (c == "\t") {
      do { result = result " "; col++ } while (col % 4 != 1)
    } else {
      result = result c
      col++
    }
  }
  return result
}


# add_line_to_tree -- close and create blocks >= level and add the line
function add_line_to_tree(stack, level, line, curblock, result,
			  curtype, h, a, f)
{
  # A recursive function that checks the line against each block in
  # the stack of open blocks, starting from the outermost block (the
  # bottom of the stack). At each level in the stack, it checks what
  # to do: add the line to this block, close the block (and its
  # children) and possibly create a new block in its stead, or pass
  # the line on to be compared to the next level, after possibly
  # removing a prefix.
  #
  # E.g., if the current level is a blockquote and the line starts
  # with a ">", remove that and let the nested blocks determine what
  # to do with the rest of the line.

  # printf "add_line_to_tree(..., %d, \"%s\",...)\n",
  #   level, line > "/dev/stderr"

  h = type_of_line(line, a)

  if (level > size(stack)) {
    # At the top of the stack. Add a new block and put the line in it
    # (unless it is a blank line, which adds no block).
    #
    # printf " at top\n" > "/dev/stderr"
    assert(empty(curblock), "empty(curblock)")
    if (h == "blank-line") {
      # Nothing to do
    } else if (h == "indented-code") {
      open_block(stack, result, h, "<pre><code>")
      push(curblock, a["content"])
    } else if (h == "blockquote") {
      open_block(stack, result, h, "<blockquote>\n")
      open_block(stack, result, "placeholder", "")
      add_line_to_tree(stack, level + 1, a["content"], curblock, result)
    } else if (h == "thematic-break") {
      open_block(stack, result, h, "<hr />\n")
    } else if (h == "heading") {
      open_block(stack, result, h " " a["level"], "<h" a["level"] ">")
      push(curblock, a["content"])
    } else if (h == "list") {
      open_block(stack, result, h " " a["indent"] " " a["type"] " " a["start"],
	a["type"] ~ /[*+-]/ ? "<ul>\n" :
		 a["start"] ~ /^0*1$/ ? "<ol>\n" :
		 "<ol start=\"" (0 + a["start"]) "\">\n")
      open_block(stack, result,
	"item " a["indent"] " " a["type"] " " a["start"], "<li>\n")
      open_block(stack, result, "placeholder", "")
      add_line_to_tree(stack, level + 2, a["content"], curblock, result)
    } else if (h == "paragraph") {
      open_block(stack, result, h, "<p>")
      add_line_to_tree(stack, level, a["content"], curblock, result)
    } else if (h == "fenced-code") {
      open_block(stack, result, h " " a["indent"] " " a["type"],
	"<pre><code" (a["class"] ? " class=\"" a["class"] "\"" : "") ">")

    } else if (h == "html-block-verbatim") {
      # print "Opening html-block-verbatim: " line > "/dev/stderr"
      open_block(stack, result, h, "")
      push(curblock, line)
      if (line ~ /<\/([Ss][Cc][Rr][Ii][Pp][Tt]|[Pp][Rr][Ee]|[Ss][Tt][Yy][Ll][Ee])>/)
	# line contains the end tag as well, end the block immediately.
	close_blocks(stack, level, curblock, result)
    } else if (h == "html-block-comment") {
      open_block(stack, result, h, "")
      push(curblock, line)
      if (line ~ /-->/) # line also contains "-->", end the block immediately.
	close_blocks(stack, level, curblock, result)
    } else if (h == "html-block-pi") {
      open_block(stack, result, h, "")
      push(curblock, line)
      if (line ~ /\?>/) # line also contains "?>", end the block immediately.
	close_blocks(stack, level, curblock, result)
    } else if (h == "html-block-decl") {
      open_block(stack, result, h, "")
      push(curblock, line)
      if (line ~ />/) # line also contains ">", end the block immediately.
	close_blocks(stack, level, curblock, result)
    } else if (h == "html-block-cdata") {
      open_block(stack, result, h, "")
      push(curblock, line)
      if (line ~ /]]>/) # line also contains "]]>", end the block immediately.
	close_blocks(stack, level, curblock, result)
    } else if (h == "html-block") {
      # print "Opening html-block: " line > "/dev/stderr"
      open_block(stack, result, h, "")
      push(curblock, line)
    } else if (h == "html-block-tag") {
      # print "Opening html-block-tag: " line > "/dev/stderr"
      open_block(stack, result, h, "")
      push(curblock, line)

    } else {
      assert(0, "Unhandled line type " h " in add_line_to_tree")
    }

  } else {
    # Compare the line against the block at this level. Depending on
    # the type of the current block and its parameters (such as its
    # indent level or list marker style), and depending on the type of
    # the line, determine what to do.
    #
    split(item(stack, level), curtype)
    # printf " in %s\n", item(stack, level) > "/dev/stderr"
    switch (curtype[1]) {
    case "placeholder":		# Newly added blockquote or item
      close_blocks(stack, level, curblock, result)
      add_line_to_tree(stack, level, line, curblock, result)
      break
    case "paragraph":
      if (h == "indented-code" || h == "paragraph" || h == "html-block-tag" ||
	  (h == "list" && a["content"] == "") ||
	  (h == "list" && a["type"] ~ /[.)]/ && a["start"] != "1")) {
	# The line can be added to the current block as text. Remove
	# leading spaces. (A list item with an empty line, or a
	# numbered list item with a number other than "1.", are
	# considered to be paragraph continuation lines, rather than
	# list items.)
	# print "adding to paragraph (" h ") \"" line "\""
	# > "/dev/stderr"
	push(curblock, awk::gensub(/^\s+/, "", 1, line))
      } else {
	# The line indicates the start of a new block. Close the
	# paragraph and call self recursively to add that new block to
	# the stack.
	# print "closing paragraph to add (" h ") \"" line "\"" > "/dev/stderr"
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "indented-code":
      if (h == "indented-code" || h == "blank-line") {
	# The line can be added to the current block as text.
	push(curblock, a["content"])
      } else {
	# The line indicates the start of a new block. Close the
	# indented-code block and call self recursively to add a new
	# block to the stack.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "heading":
      # A heading block is always one line, so this new line closes
      # the heading block. Recursively call self to create a new block
      # for this line.
      close_blocks(stack, level, curblock, result)
      add_line_to_tree(stack, level, line, curblock, result)
      break;
    case "blockquote":
      if (h == "blockquote") {
	# The line starts with ">", so it is a continuation of the
	# current blockquote. Remove the ">" and pass on the remainder
	# to the next level.
	add_line_to_tree(stack, level + 1, a["content"], curblock, result)

      } else if ((h == "indented-code" || h == "paragraph") &&
		 top(stack) == "paragraph") {
	# The line does not start with ">", but there is currently a
	# paragraph open and the line is a valid paragraph line, so
	# treat the line as a "lazy continuation line" and pass it on
	# unmodified, to be handled by that paragraph.
	add_line_to_tree(stack, size(stack), line, curblock, result)
      } else {
	# The line does not start with ">" and is not a lazy
	# continuation, so it means the end of the blockquote. Close
	# the blockquote and call self recursively to make a new
	# block.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "list":
      # Use the indent of the most recent item, rather than of the
      # first. The following should set curtype[1] to "item" and
      # curtype[2] to the indent of the item.
      split(item(stack, level + 1), curtype)
      if (h == "blank-line") {
	# A blank line does not end a list, but it may end one of its
	# descendants. Pass it on.
	add_line_to_tree(stack, level + 1, a["content"], curblock, result)
      } else if (indent_size(line) >= curtype[2]) {
	# The line is indented at least to the same level as the
	# current item of this list, which means it does not end this
	# item. Reduce the indent of the line and pass it on to be
	# handled by the current list item and its children.
	# print "line = \"" line "\"" > "/dev/stderr"
	# print "  indent = " indent_size(line) > "/dev/stderr"
	# print "  stack = \"" item(stack, level + 1) "\"" > "/dev/stderr"
	# print "  curtype[2] = " curtype[2] > "/dev/stderr"
	add_line_to_tree(stack, level + 1, unindent_line(line, curtype[2]),
			 curblock, result)
      } else if (h == "list" && a["type"] == curtype[3]) {
	# The line is a list item of the same type as the current
	# list. Close the current item and open a new one.
	close_blocks(stack, level + 1, curblock, result)
	open_block(stack, result,
	  "item " a["indent"] " " a["type"] " " a["start"], "<li>\n")
	open_block(stack, result, "placeholder", "")
	add_line_to_tree(stack, level + 2, a["content"], curblock, result)
      } else if ((h == "paragraph" || h == "indented-code") &&
		 top(stack) == "paragraph") {
	# There is currently a paragraph open and the line is
	# compatible with being a lazy continuation line. Pass it on
	# to that paragraph.
	add_line_to_tree(stack, size(stack), line, curblock, result)
      } else {
	# The line is of any other kind, so close the current list and
	# call self recursively to create a new block for this line.
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      }
      break
    case "item":
      # All the logic is in "list". This just passes the line on to
      # the next level.
      add_line_to_tree(stack, level + 1, line, curblock, result)
      break
    case "fenced-code":
      if (h == "fenced-code" && a["type"] ~ curtype[3] && a["info"] == "")
	# The line is a fenced code marker (``` or ~~~) of the same
	# type and at least as long as the marker that started the
	# fenced code block. And it does not have an info string. So
	# this is the end of the block.
	close_blocks(stack, level, curblock, result)
      else
	# Any other line is added verbatim to this block, except that
	# its indent is reduced by the indent of the code fence that
	# started the block.
	push(curblock, unindent_line(line, curtype[2]))
      break
    case "thematic-break":
      # A thematic break is always one line, so this new line closes
      # the thematic break. Then recursively call self to create a
      # block for this new line.
      close_blocks(stack, level, curblock, result)
      add_line_to_tree(stack, level, line, curblock, result)
      break

    case "html-block-verbatim":
      # Add the line verbatim.
      push(curblock, line)
      # A script, pre or style block ends when the line contains
      # </script>, </pre> or </style>.
      if (line ~ /<\/([Ss][Cc][Rr][Ii][Pp][Tt]|[Pp][Rr][Ee]|[Ss][Tt][Yy][Ll][Ee])>/)
	close_blocks(stack, level, curblock, result)
      break
    case "html-block-comment":
      # Add the line verbatim.
      push(curblock, line)
      # An html-block-comment ends when the line contains "-->"
      if (line ~ /-->/) close_blocks(stack, level, curblock, result)
      break;
    case "html-block-pi":
      # Add the line verbatim.
      push(curblock, line)
      # An html-block-pi ends when the line contains "?>"
      if (line ~ /?>/) close_blocks(stack, level, curblock, result)
      break;
    case "html-block-decl":
      # Add the line verbatim.
      push(curblock, line)
      # An html-block-decl ends when the line contains ">"
      if (line ~ />/) close_blocks(stack, level, curblock, result)
      break;
    case "html-block-cdata":
      # Add the line verbatim.
      push(curblock, line)
      # An html-block-cdata ends when the line contains "]]>"
      if (line ~ /]]>/) close_blocks(stack, level, curblock, result)
      break;
    case "html-block":
      # A blank line ends the HTML block. Other lines are added verbatim.
      if (h == "blank-line") {
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      } else {
	push(curblock, line)
      }
      break
    case "html-block-tag":
      # A blank line ends the HTML block. Other lines are added verbatim.
      if (h == "blank-line") {
	close_blocks(stack, level, curblock, result)
	add_line_to_tree(stack, level, line, curblock, result)
      } else {
	push(curblock, line)
      }
      break

    default:
      assert(0, "Unhandled block type " curtype[1] " in add_line_to_tree")
    }
  }
}


# type_of_line -- determine the type of line and return its parts
function type_of_line(line, parts,	a, h)
{
  # The parts array is filled with noteworthy parts of the line:
  #
  # "content": The content of the line after any markers. (blank-line,
  #   indented-code, blockquote, list, heading, paragraph)
  #
  # "type": The marker. (fenced-code, list)
  #
  # "info": The info string. (fenced-code) Not currently used by any
  #   other function.
  #
  # "class": A text of the form "language-xxx", where xxx is the first
  #   word of "info", or the empty string if there is no info. (A
  #   "word" is what comes before the first space, or the whole info,
  #   if it contains no space.) (fenced-code)
  #
  # "indent": A number >= 0 indicating in which column the "content"
  #   part starts, after expanding tabs, where tabs stops are assumed
  #   every 4 characters. (list, fenced-code)
  #
  # "start": A string with a decimal number indicating the number of
  #   the first item in an ordered list. Only defined if "type" is
  #   "." or ")" (list)
  #
  # "level": A number between 1 and 6 indicating the heading
  #   level. (heading)
  #
  # Note that unused array items are not cleared. The caller (the
  # add_line_to_tree() function) should only inspect array items that
  # are defined for the type of line.

  if (match(line, /^ *$/)) {
    parts["content"] = unindent_line(line, 4)
    return "blank-line"
  } else if (indent_size(line) >= 4) {
    parts["content"] = unindent_line(line, 4)
    return "indented-code"
  } else if (match(line, /^ *((```+)([^`]*)|(~~~+)(.*))$/, a)) {
    parts["type"] = a[2] a[4]
    parts["info"] = awk::gensub(/^\s+/,"", 1,
       awk::gensub(/\s+$/, "", 1, unesc_md(a[3] a[5])))
    parts["class"] = parts["info"] ?
      "language-" awk::gensub(/\s.*/, "", 1, parts["info"]) : ""
    parts["indent"] = indent_size(line)
    return "fenced-code"
  } else if (match(line, /^ *>\s?(.*)/, a)) {
    parts["content"] = a[1]
    return "blockquote"
  } else if (match(line, /^ *((\* *){3,}|(- *){3,}|(_ *){3,})$/)) {
    return "thematic-break"
  } else if (match(line, /^( *)([*+-])( (.*))?$/, a)) {
    parts["content"] = 4 in a ? a[4] : ""
    sub(/^\s+$/, "", parts["content"]) # Only spaces
    parts["type"] = a[2]
    if (parts["content"] == "") # Starts with empty line
      parts["indent"] = length(a[1]) + 2
    else if (indent_size(parts["content"]) >= 4) # Starts with indented code block
      parts["indent"] = length(a[1]) + 2
    else
      parts["indent"] = indent_size(a[1] " " a[3])
    # print "type of \"" line "\" is list" > "/dev/stderr"
    # print "indent = " parts["indent"] > "/dev/stderr"
    return "list"
  } else if (match(line, /^( *)([0-9]{1,9})([.)])( (.*))?$/, a)) {
    parts["content"] = 5 in a ? a[5] : ""
    sub(/^\s+$/, "", parts["content"]) # Only spaces
    parts["start"] = a[2]
    parts["type"] = a[3]	# "." or ")"
    h = awk::gensub(/./, " ", "g", a[2])
    if (parts["content"] == "") # Starts with empty line
      parts["indent"] = length(a[1]) + length(a[2]) + 2
    else if (indent_size(parts["content"]) >= 4) # Starts with indented code block
      parts["indent"] = length(a[1]) + length(a[2]) + 2
    else
      parts["indent"] = indent_size(a[1] h " " a[4])
    return "list"
  } else if (match(line, /^ *(#{1,6})( +(.*))?$/, a)) {
    parts["content"] = 3 in a ? a[3] : ""
    sub(/^\s+$/, "", parts["content"]) # Make empty if it only has spaces
    parts["level"] = length(a[1])
    sub(/(^| +)#+ *$/, "", parts["content"]) # Remove any #'s at the end
    return "heading"

  } else if (match(line, /^ {,3}<([a-zA-Z0-9]+)/, a) &&
      tolower(a[1]) ~ /^(script|pre|style)$/) {
    return "html-block-verbatim"
  } else if (match(line, /^ {,3}<!--/)) {
    return "html-block-comment"
  } else if (match(line, /^ {,3}<\?/)) {
    return "html-block-pi"
  } else if (match(line, /^ {,3}<![A-Z]/)) {
    return "html-block-decl"
  } else if (match(line, /^ {,3}<!\[CDATA\[/)) {
    return "html-block-cdata"
  } else if (match(line, /^ {,3}<\/?([a-zA-Z][a-zA-Z0-9]*)(\s+|\/?>|$)/, a) &&
      tolower(a[1]) ~ /^(address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|section|source|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)$/) {
    return "html-block"
  } else if ((match(line, /^ {,3}<([a-zA-Z][a-zA-Z0-9-]*)(\s+[a-zA-Z_:][a-zA-Z0-9_.:-]*(\s*=\s*([^[:space:]"'=<>.]+|"[^"]*"|'[^']*'))?)*\s*\/?>\s*$/, a) ||
	      match(line, /^ {,3}<\/([a-zA-Z][a-zA-Z0-9-]*)\s*>\s*$/, a)) &&
      tolower(a[1]) !~ /^(script|style|pre)$/) {
    return "html-block-tag"

  } else if (match(line, /^ *(.*)$/, a)) {
    parts["content"] = a[1]
    return "paragraph"
  }
  assert(!"Cannot happen", "Cannot happen")
}


# indent_size -- how much a line is indented, assuming tab stops at 4 spaces
function indent_size(line,	chars, i, n, r)
{
  n = split(line, chars, //)
  r = 0
  for (i = 1; i <= n; i++)
    if (chars[i] == " ") r++
    else if (chars[i] == "\t") r += 4 - (r + 4) % 4
    else return r
  return r
}


# unindent_line -- remove up to n spaces, assuming tab stops at 4 spaces
function unindent_line(line, n,		i)
{
  i = 0
  while (i < n) {
    if (line ~ /^\t/) {i += 4 - (i + 4) % 4; line = substr(line, 2)}
    else if (line ~ /^ /) {i++; line = substr(line, 2)}
    else i = n			# No more spaces or tabs to remove
  }
  # If the last tab removed too much, add spaces in front.
  while (i > n) {line = " " line; i--}
  return line
}


# open_block -- add a block to the stack and its start tag to the result queue
function open_block(stack, result, type, tag)
{
  # printf "open_block(..., \"%s\", %s)\n", type,
  #   awk::gensub(/\n/, " ", "g", tag) > "/dev/stderr"
  push(stack, type)
  push(result, tag)
}


# close_blocks -- serialize a block and its children into result and remove them
function close_blocks(stack, level, curblock, result,	curtype, h)
{
  # A recursive function that serializes the block at the given level,
  # and all blocks contained within it, to HTML. It adds the HTML to
  # the array "result" (which is a queue of HTML fragments). The start
  # tags of all blocks are already in the array. Only the contents of
  # the final block (which is in the curblock parameter) and the end
  # tags of all block have to be added. The blocks are then closed,
  # i.e., removed from the stack.
  #
  # Depending on the kind of block at the top (paragraph, heading,
  # indented code or fenced code), the contents are parsed as inline
  # markdown or copied as-is.
  #
  # "curblock" is an array (queue) of lines without newlines.

  if (level <= size(stack)) {
    split(item(stack, level), curtype)
    # printf "close_blocks(..., %d, \"%s\",...)\n",
    #   level, item(stack, level) > "/dev/stderr"
    switch (curtype[1]) {
    case "placeholder":		# Newly opened blockquote or item
      break;
    case "paragraph":
      push(result, awk::gensub(/ +$/, "", 1,
	to_inline_html(join(curblock, "\n"))))
      destroy(curblock)
      push(result, "</p>\n")
      break
    case "blockquote":
      close_blocks(stack, level + 1, curblock, result)
      push(result, "</blockquote>\n")
      break
    case "heading":
      push(result, awk::gensub(/ +$/, "", 1,
	to_inline_html(join(curblock, "\n"))))
      destroy(curblock)
      push(result, "</h" curtype[2] ">\n")
      break
    case "list":
      close_blocks(stack, level + 1, curblock, result)
      push(result, curtype[3] ~ /[*+-]/ ? "</ul>\n" : "</ol>\n")
      break
    case "item":
      close_blocks(stack, level + 1, curblock, result)
      push(result, "</li>\n")
      break
    case "indented-code":
      h = join(curblock, "\n")
      sub(/\n+$/, "", h)	# Empty lines before the end are removed
      if (h != "") push(result, esc_html(h) "\n")
      destroy(curblock)
      push(result, "</code></pre>\n")
      break
    case "thematic-break":
      break
    case "fenced-code":
      h = join(curblock, "\n")
      if (h != "") push(result, esc_html(h) "\n")
      destroy(curblock)
      push(result, "</code></pre>\n")
      break

    case "html-block-verbatim":
    case "html-block-comment":
    case "html-block-pi":
    case "html-block-decl":
    case "html-block-cdata":
    case "html-block":
    case "html-block-tag":
      h = join(curblock, "\n")
      if (h != "") push(result, h "\n")
      destroy(curblock)
      break;

    default:
      assert(0, "Unhandled block type: " curtype[1] " in close_blocks()")
    }

    pop(stack)
  }
}


# unesc_md -- unescape backslashed punctuation & character entities in markdown
function unesc_md(s,	t, a, h, n)
{
  # Loop over s looking for backslash + punctuation or HTML character
  # entities. Unknown entity references are copied as is. Backslashes
  # not followed by punctuation are copied as-is, Ampersands not
  # followed by an entity name or number are also copied as-is.
  #
  t = ""
  while (match(s, /\\([]!"#$%&'()*+,./:;<=>?@[\\^_`{|}~}-])|&([a-zA-Z][a-zA-Z0-9.-]*|#([Xx][0-9a-fA-F]{1,6}|[0-9]{1,7}));/, a)) {
    if (a[0] ~ /^\\/) {
      h = a[1]
    } else if (a[2] ~ /^#[Xx]/) {
      n = awk::strtonum("0" a[3])
      h = sprintf("%c", n ? n : 65533) # Replace U+0000 by U+FFFD
    } else if (a[2] ~ /^#/) {
      n = 0 + a[3]
      h = sprintf("%c", n ? n : 65533) # Replace U+0000 by U+FFFD
    } else if (a[2] in htmlmathml::ent) {
      h = htmlmathml::ent[a[2]]
    } else {
      h = a[0]			# Unknown named entity, leave as-is
    }
    t = t substr(s, 1, RSTART - 1) h
    s = substr(s, RSTART + RLENGTH)
  }

  return t s
}


# esc_html -- escape HTML delimiters
function esc_html(s)
{
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  gsub(/"/, "\\&quot;", s)
  return s
}


# esc_url -- %-escape certain characters for use in a URL
function esc_url(s)
{
  gsub(/\\/, "%5C", s)
  gsub(/ /, "%20", s)
  # gsub(/\[/, "%5B", s)	# Not necessary, but matches the spec examples
  # gsub(/\]/, "%5D", s)	# Not necessary, but matches the spec examples
  # gsub(/`/, "%60", s)		# Not necessary, but matches the spec examples
  gsub(/"/, "%22", s)		# Not necessary, but matches the spec examples
  gsub(/ /, "%C2%A0", s)	# Not necessary, but matches the spec examples
  return s
}


# Functions to handle queues and stacks.
#
# A queue or stack is automatically initialized the first time a value
# is added.
#
# Calling pop(), top(), unshift() or first() on an empty queue or
# stack returns an unassigned value, i.e., typeof() on that value
# yields "unassigned".
#
# Queues and stacks are implemented as arrays. The values are stored
# at consecutive numeric indices in the array: x[n], x[n+1], x[n+2],
# etc. The special entries x["first"] and x["last"] contain the
# indices of the first and last values in the queue/stack. If
# x["last"] < x["first"], or if x is uninitialized, it means the
# queue/stack is empty.


# push -- add a value to a stack or a queue, return its index
function push(stack, value)
{
  # If stack is uninitialized, initialize it
  if (awk::typeof(stack) == "untyped") {
    stack["first"] = 1
    stack["last"] = 0
  }
  stack[++stack["last"]] = value
  return stack["last"]
}


# pop -- return the top value on the stack and remove it from the stack
function pop(stack,	v)
{
  if (! empty(stack)) {
    v = stack[stack["last"]]
    delete stack[stack["last"]]
    stack["last"]--
  }
  return v
}


# top -- return the top value of a stack
function top(stack)
{
  return stack[stack["last"]]
}


# shift -- add an item at the start of a queue, return its index
function shift(queue, value)
{
  # If the queue is uninitialized, initialize it
  if (awk::typeof(queue) == "untyped") {
    queue["first"] = 1
    queue["last"] = 0
  }
  queue[--queue["first"]] = value
  return queue["first"]
}


# unshift -- return the first item in a queue and remove it from the queue
function unshift(queue,		v)
{
  if (! empty(queue)) {
    v = queue[queue["first"]]
    delete queue[queue["first"]]
    queue["first"]++
  }
  return v
}

# first -- return the first item in a queue
function first(queue)
{
  return queue[queue["first"]]
}


# item -- get the n'th value of a queue or stack
function item(queue, n)
{
  return queue[queue["first"] + n - 1]
}


# destroy -- make a stack or queue empty
function destroy(queue)
{
  while (! empty(queue)) pop(queue)
}


# join -- join a stack or queue of strings into a single string with separators
function join(queue, sep,	result, i)
{
  if (empty(queue)) return ""
  i = queue["first"]
  result = queue[i]
  while (++i <= queue["last"]) result = result sep queue[i]
  return result
}


# size -- number of values in a queue or stack
function size(queue)
{
  if (awk::typeof(queue) != "array") return 0
  else return queue["last"] + 1 - queue["first"]
}


# empty -- check if a stack or a queue is empty
function empty(stack)
{
  if (awk::typeof(stack) != "array") return 1
  else return stack["last"] < stack["first"]
}


# assert -- assert that a condition is true, otherwise exit
function assert(condition, string)
{
  if (! condition) {
    printf "%s:%d: assertion failed: %s\n",
      FILENAME, FNR, string > "/dev/stderr"
    awk::_assert_exit = 1
    exit 1
  }
}


