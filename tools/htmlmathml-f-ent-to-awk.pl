#!/usr/bin/env perl
#
# Tool to create htmlmathml.awk from
# https://www.w3.org/2003/entities/2007/htmlmathml-f.ent
#
# Expects lines such as
#
#   <!ENTITY npart "&#x02202;&#x00338;" ><!--PARTIAL DIFFERENTIAL with slash -->
#
# The quoted replacement text contains text and numeric entities. If
# the replacement text contains a character that would be an XML
# delimiter, that delimiter is not written as "&#nnn;" but as
# "&#38#nnn;". E.g., the replacement for "&lt;" would be "&#60;"
# (which stands for "<"), but is written as "&#38;#60;".
#
# Each entity line creates an Awk array entry like
#
#    htmlmathml_ent["part"] = "∂̸"

use warnings;
use strict;
use feature 'unicode_strings';

binmode(STDOUT, ":utf8");
print "# Defines the array htmlmathml::ent with replacements for\n";
print "# all named character entities of HTML.\n";
print "# This file is in UTF-8.\n\n";
print "\@namespace \"htmlmathml\"\n\n";
print "BEGIN {\n";

while (<>) {
  if (/<!ENTITY\s+([a-zA-Z][a-zA-Z0-9.-]*)\s*"([^"]*)"/) {
    my ($n, $v) = ($1, $2);	# Entity name and value

    # Replace hexadecimal and decimal character entities. Some
    # replacements replace a name by another entity: (e.g., "lt" ->
    # "&#38;#60") because the actual character would not be legal XML.
    # We replace such entities as well.
    $v =~ s/&#(?:38;#)?(?:(x)([0-9a-f]+)|([0-9]+));/$1 ? chr(hex($2)) : chr($3)/gie;

    # Replace control characters, quotes and backslashes by hexadecimal escapes.
    $v =~ s/[\x00-\x1F]|"|\\/sprintf("\\x%02x", ord($&))/ge;

    print "ent[\"$n\"] = \"$v\"\n";
  }
}

print "}\n";
