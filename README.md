# gf-markdown-awk
Awk library to convert GitHub-flavored markdown to HTML or to plain text.

To use this to make a program that converts markdown to HTML, write the following Awk code:

    @include "markdown.awk"
    { lines = lines $0 "\n" }
    END { printf "%s", markdown::to_html(lines) }

(Requires the Gnu version of Awk, because it uses ‘@include’ and namespaces.)

More documentation is included in the `markdown.awk` file.

## What is this for?
There are several programs that convert markdown ([GitHub-flavored markdown](https://github.github.com/gfm/) or other dialects) to HTML and this one isn't the best (see [limitations](#limitations) below). So why this code?

It's not a program, but a library. (Although it only requires three lines to make it a program, see above). And in particular it is a library for *Awk.* It is meant for people who need to add markdown support to an Awk program.

You could, of course, call an external program from your Awk script to convert markdown to HTML. But this library provides two extra functions that may occasionally be handy and that existing programs don't provide. (At least I haven't found any.) And that is the ability to parse inline markdown only, i.e., bold, italics, links, etc., while ignoring paragraphs, lists, etc.; and the ability to strip markdown from text to retain just the plain text content.

The former is provided by the function `markdown::to_inline_html()`, the latter by the function `markdown::to_text()`.

## Limitations

The code does not currently implement ‘setexts headings’ (headings that are underlined instead of prefixed with one or more ‘#’ characters), ‘tight lists’ (lists where the generated HTML looks like `<li>item</li>` instead of `<li><p>item</p></li>`), tables, and CDATA sections (`<!CDATA[...]>`).

Character entities, such as `&eacute;` and `&#233;`, only expand correctly in UTF-8 locales.

The code does not currently implement extended autolinks (bare URLs, email addresses and certain domain names).

The code does not currently implement the task list extension, i.e., `[x]` is not transformed into a checkbox.

The tables extension is not implemented.

Link reference definitions are not supported.

The code does not fully implement the Disallowed Raw HTML extension: Tags like `<xmp>`, `<iframe>` and `<noembed>` are only filtered when they occur inline, but currently not when they occur in an HTML block.

## Differences from the specification

Here are the known differences from the [specification](https://github.github.com/gfm/):

### Tabs are expanded

The specification says that tabs are replaced by spaces only when they take part in determining the indentation of an input line. Tabs inside the contents of a line are passed through unchanged. This implementation expands all tabs to spaces. (But that might change in the future.)

### `>` in disallowed raw HTML

When encountering disallowed tags (`<title>`, `<textarea>`, `<style>` and others), this implementation replaces their `<` and `>` by `&lt;` and `&gt;`. The specification only replaces the `<`.

### Backslash in HTML tags

The specification does not allows backslashes to occur in HTML tags, except just before a newline. The implementation doesn't allow them before a newline either.

### No nested links

Not a difference from the specification, but a difference from the cmark and cmark-gfm implementations: Input such as such as `[<http://example.org/>](url)` produces `[<a href="http://example.org/">http://example.org/</a>](url)`. (If multiple link definitions appear nested inside each other, the inner-most definition is used.) But cmark/cmark-gfm produce `<a href="url"><a href="http://example.org/">http://example.org/</a></a>`.


## Bugs

Two empty lines at the start of a list item should end the item (i.e., create an empty item), but don't. E.g.,

``` markdown
-

  Foo
```

should create an empty list item and a paragraph, but instead creates a list item with the ‘Foo’ inside. (Workaround: Reduce the indent of `Foo’.)

‘Rule 10’ is not implemented. It says that `*foo**bar*` should be `<em>foo**bar</em>`, but the current implementation produces `<em>foo</em<em>bar</em>` instead.

When two potential emphasis spans overlap, it is not always the first that takes precedence. (Violates ‘rule 15’.)

