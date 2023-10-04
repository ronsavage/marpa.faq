#!/usr/bin/env perl

use 5.018;

use File::Slurper qw/read_lines write_text/;

# ------------------------------------------------

my($in_file_name)	= 'guide/faq.txt';
my($out_file_name)	= 'guide/faq.new';
my(@lines)		= read_lines($in_file_name);

say "$in_file_name. Lines: @{[$#lines + 1]}";

for my $i (@lines)
{
	
}

write_text($out_file_name, join("\n", @lines) . "\n");

#say "$in_file_name. Lines: @{[$#lines + 1]}";

