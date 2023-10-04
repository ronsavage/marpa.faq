#!/usr/bin/env perl

use 5.018;

use File::Slurper qw/read_lines write_text/;

# ------------------------------------------------

my($in_file_name)	= 'guide/faq.txt';
my($out_file_name)	= 'guide/faq.new';
my(@lines)		= read_lines($in_file_name);

say "Processing: $in_file_name. Line count: @{[$#lines + 1]}";

my(%messages, %offsets);
my($link_number, $q_number, $text);

$offsets{start_of_toc}	= 99999;
$offsets{end_of_toc}	= 99999;

for my $i (0 .. $#lines)
{
	# Find start and end of TOC.

	if ($lines[$i] eq '##Table of Contents grouped by Topic')
	{
		$offsets{start_of_toc} = $i;

		say "Start of TOC at line $i";
	}
	elsif ($lines[$i] eq '##Answers grouped by Topic')
	{
		$offsets{end_of_toc} = $i;

		say "End of TOC @ at line $i";
	}
	
	# Stockpile Questions and their ids.

	if ( ($i >= $offsets{start_of_toc}) && ($i <= $offsets{end_of_toc}) )
	{
#		* [102 What is Libmarpa?](#q102)

		if ($lines[$i] =~ /\[(\d+)\s+([^]]+)\]\(\#q(\d+)\)/)
		{
			$q_number	= $1;
			$text		= $2;
			$link_number	= $3;
			say "Line: @{[$i + 1]} Q: <$q_number>. Link: <$link_number>. <$text>";

			if ($q_number != $link_number)
			{
				say "Error. Mismatch between q number and link number";

				exit;
			}
		}
	}
}

write_text($out_file_name, join("\n", @lines) . "\n");

