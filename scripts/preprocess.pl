#!/usr/bin/env perl

use 5.018;

use boolean ':all'; # For isFalse().

use Data::Dumper::Concise; # For Dumper().

use File::Slurper qw/read_lines write_text/;

use Getopt::Long;

use Pod::Usage;

use Syntax::Keyword::Match;

use Time::Piece;

# Sample link names:
# o * [102 What is Libmarpa?](#q102)
#	or
# o * [155 Where can I find a timeline (history) of parsing?](#q155)

# Sample link references:
# o See also <a href='#q6'>Q 6</a>.
#	or
# o See also <a href='#q112'>Q 112</a> and <a href='#q114'>Q 114</a>.

# Sample link target definitions (2 successive lines):
# o <a name = 'q102'></a>
# o 102 What is Libmarpa?
#	or
# o <a name = 'q155'></a>
# o 155 Where can I find a timeline (history) of parsing?

our($qr_link_name)	= qr/(.+?)(\d+)\s+(.+]\(#q)(\d+)(.+)/;	# Sets $1, $2, $3, $4 and $5.
our($qr_link_reference)	= qr/(.+?'#q)(\d+)('>Q )(\d+)(<)/;	# Sets $1, $2, $3, $4 and $5.
our($qr_link_target)	= qr/a\s+name\s*=\s*'q(\d+)'><\/a>/;	# Sets $1.

# ------------------------------------------------

sub generate_ids
{
	my($lines, $link2question, $offsets, $option, $question2link, $sections_in_body, $sections_in_toc) = @_;

	my($debug);

	if ($debug)
	{
		say "scalar keys link2question:    ", scalar %$link2question;
		say "scalar keys question2link:    ", scalar %$question2link;
		say "scalar keys sections_in_toc:  ", scalar %$sections_in_toc;
		say "scalar keys sections_in_body: ", scalar %$sections_in_body;
	}

	my(%section_locations);

	$section_locations{toc}		= {};
	$section_locations{body}	= {};

	renumber_sections('ToC', $lines, $option, $section_locations{toc}, $sections_in_toc);
	renumber_sections('Body', $lines, $option, $section_locations{body} ,$sections_in_body);

	renumber_questions($lines, $offsets, $option, \%section_locations);

} # End of generate_ids.

# ------------------------------------------------

sub renumber_questions
{
	my($lines, $offsets, $option, $section_locations) = @_;

	# Scan ToC looking for questions names.
	# Also, put flags in these array refs to limit scanning of questions per section.

	my($toc_line_numbers)				= [sort keys %{$$section_locations{toc} }];
	my($body_line_numbers)				= [sort keys %{$$section_locations{body} }];
	$$toc_line_numbers[$#$toc_line_numbers + 1]	= $$body_line_numbers[0];
	$$body_line_numbers[$#$body_line_numbers + 1]	= $#$lines;

	# Report start of ToC sections, plus just past.

	if ($$option{report} == 7)
	{
		say "Scanning ToC.  Found $$toc_line_numbers[$_]: $$lines[$$toc_line_numbers[$_] ]" for (0 .. $#$toc_line_numbers);
		say;
	}

	# Stockpile map of old question #s to new ones.
	# %question_map{old q #} = new q #.

	my(%question_map, $question_number);

	my($question_count) = 0;

	for my $i ($$toc_line_numbers[0] .. $$toc_line_numbers[$#$toc_line_numbers])
	{
		#say "Scanning $$lines[$i]" if ($$option{report} == 7);

		# $qr_link_name = qr/(.+?)(\d+)\s+(.+]\(#q)(\d+)(.+)/;

		if ($$lines[$i] =~ $qr_link_name)  # Sets $1, $2, $3, $4 and $5.
		{
			# Sample link names:
			# o * [102 What is Libmarpa?](#q102)
			#	or
			# o * [155 Where can I find a timeline (history) of parsing?](#q155)

			$question_number		= $4;
			$question_map{$question_number}	= ++$question_count;

			say "ToC Question old #: $question_number. New #: $question_count" if ($$option{report} == 7);
		}
	}

	my($save_line);

	for my $i ($$toc_line_numbers[0] .. $$toc_line_numbers[$#$toc_line_numbers])
	{
		# $qr_link_name = qr/(.+?)(\d+)\s+(.+]\(#q)(\d+)(.+)/;

		if ($$lines[$i] =~ $qr_link_name)  # Sets $1, $2, $3, $4 and $5.
		{
			$save_line	= $$lines[$i];
			$$lines[$i]	=~ s/$qr_link_name/$1$question_map{$2} $3$question_map{$4}$5/;

			if ($$lines[$i] ne $save_line)
			{
				say "1 Was: $save_line\n  Is:  $$lines[$i]" if ($$option{report} == 8);
			}
		}
	}

	# Report start of Body sections, plus last line.

	if ($$option{report} == 8)
	{
		say "Scanning Body. Found $$body_line_numbers[$_]: $$lines[$$body_line_numbers[$_] ]" for (0 .. $#$body_line_numbers);
		say;
	}

	# Sample link references:
	# o See also <a href='#q6'>Q 6</a>.
	# o See also <a href='#q112'>Q 112</a> and <a href='#q114'>Q 114</a>.

	for my $i ($$body_line_numbers[0] .. $$body_line_numbers[$#$body_line_numbers])
	{
		$save_line	= $$lines[$i];
		$$lines[$i]	=~ s/$qr_link_reference/$1$question_map{$2}$3$question_map{$4}$5/g; # Sets $1, $2, $3, $4 and $5.

		if ($$lines[$i] ne $save_line)
		{
			say "2 Was: $save_line\n  Is:  $$lines[$i]" if ($$option{report} == 8);
		}
	}

} # End of renumber_questions.

# ------------------------------------------------

sub renumber_sections
{
	my($context, $lines, $option, $section_locations, $sections) = @_;

	# Invert the hashref %$sections so the line numbers become keys.
	# Pad line numbers on left with zeros to assist sorting.

	for (keys %$sections)
	{
		$$section_locations{sprintf('%04i', $$sections{$_})} = $_;
	}

	#say map{"Process $context: $_ => $$section_locations{$_}\n"} sort keys %section_locations if ($$option{report} == 6);

	my($new_name);
	my($section_name);

	my($section_id)		= 'A';
	my($section_prefix)	= '###';

	for my $line_number (sort keys %$section_locations)
	{
		$section_name = $$section_locations{$line_number};

		say "$context: Renumbering. Line: $line_number. $section_id: $section_name" if ($$option{report} == 6);

		if ($$lines[$line_number] =~ /^$section_prefix$section_name/)
		{
			$new_name		= "$section_prefix $section_id: $section_name";
			$$lines[$line_number]	= "$section_prefix$section_id: $section_name";

			say "$context: Renumbered.  Line: $line_number. $$lines[$line_number]" if ($$option{report} == 6);
		}

		$section_id++;
	}

} # End of renumber_sections.

# ------------------------------------------------

sub report_error
{
	my($error_number, $errors, $error_parameters, $link2question, $question2link) = @_;

	say "Error #: $error_number. $$errors{$error_number}";

	my($msg) = '';

	if ($error_number <= 3)
	{
		$msg = "Line: $$error_parameters{i}. Q: <$$error_parameters{q_number}>. "
			. "Link: <$$error_parameters{link_number}>. <$$error_parameters{text}>";
	}
	elsif ($error_number <= 4)
	{
		$msg = "Line: $$error_parameters{i}. Link reference: $$error_parameters{link_reference}";
	}
	elsif ($error_number <= 6)
	{
		$msg = "Line: $$error_parameters{i}. Text: $$error_parameters{text}";
	}

	match ($error_number : ==)
	{
		case(1) {say "$msg. Other link: $$question2link{$$error_parameters{text} }"}
		case(2) {say "$msg. Other link: $$link2question{$$error_parameters{text} }"}
		case(3), case(4), case(5), case(6), case(7), case(8) {say $msg}
	}

} # End of report_error.

# ------------------------------------------------

sub run
{
	my($option)		= @_;
	my($in_file_name)	= 'guide/faq.txt';
	my($out_file_name)	= 'guide/faq.new';
	my(@lines)		= read_lines($in_file_name);
	$$option{report}	//= 0;

	say "Input file: $in_file_name. Line count: @{[$#lines + 1]}. Output file: $out_file_name";

	# Update version #. Do nothing if version # not found.

	update_version(\@lines, $option);

	# Validate ToC and Body.

	my($error_count, $link2question, $offsets, $question2link, $sections_in_body, $sections_in_toc) = validate(\@lines, $option);

	say "Error count after validation: $error_count";

	# Generate section ids (A, B, ...). Original text may have or not have ids.
	# Then, generate question ids (#q\d+).

	generate_ids(\@lines, $link2question, $offsets, $option, $question2link, $sections_in_body, $sections_in_toc);

	write_text($out_file_name, join("\n", @lines) . "\n") if ($error_count == 0);

	return $error_count;

} # End of run.

# -----------------------------------------------

sub update_version
{
	my($lines, $option)	= @_;
	my($new_version_number)	= '1.00';
	my $now			= localtime; # Must be in scalar context.
	my($qr_version_number)	= qr/Version (\d\.\d\d).+/;

	for my $i (0 .. $#$lines)
	{
		if ($$lines[$i] =~ $qr_version_number) # Sets $1.
		{
			$new_version_number	= $$option{version} || $new_version_number || $1;
			$$lines[$i]		= "Version $new_version_number. " . $now -> datetime . '.';

			say "New version: $$lines[$i]";
		}
	}

} # End of update_version.

# -----------------------------------------------

sub validate
{
	my($lines, $option) = @_;

	# Notes:
	# o %link2question(key, value) 		=> (link #, text).
	# o %question2link(key, value) 		=> (text, link #).
	# %offsets{start_of_toc, end_of_toc}	=> (line #, line #). Line numbers are 0 .. N.
	# %sections_in_body(key, value)		=> (name, line #).
	# %sections_in_toc(key, value)		=> (name, line #).

	my(%errors, $error_count, %error_parameters);
	my($link_number, $link_reference, $link_target, $link_text, %link2question, @list_of_refs);
	my(%offsets);
	my($q_number, %question2link);
	my(%references);
	my($section_name, %sections_in_toc, %sections_in_body);
	my($text);

	$errors{1}		= 'Duplicate question text';
	$errors{2}		= 'Duplicate link number';
	$errors{3}		= 'Mismatch between question number and link number';
	$errors{4}		= 'Link points to non-existant target';
	$errors{5}		= 'Section name in Body not present in ToC';
	$errors{6}		= 'Section name in ToC not present in Body';
	$errors{7}		= 'Number of sections in ToC not equal to number in Body';
	$errors{8}		= 'Link reference mismatch';
	$error_count		= 0;
	my($qr_section_name)	= qr/^###([A-Z]: )?(.+)/; # Ignore section ids added by a previous run. Sets $1.
	$offsets{start_of_toc}	= 99999;
	$offsets{end_of_toc}	= 99999;
	my($section_error)	= false;

	for my $i (0 .. $#$lines)
	{
		$error_parameters{i} = $i;

		# Find start and end of TOC.

		if ($$lines[$i] eq '##Table of Contents grouped by Topic')
		{
			$offsets{start_of_toc} = $i;

			say "Start of TOC. Line $i" if ($$option{report} == 1);
		}
		elsif ($$lines[$i] eq '##Answers grouped by Topic')
		{
			$offsets{end_of_toc} = $i;

			say "End of TOC.   Line $i" if ($$option{report} == 1);
		}
		
		# Stockpile:
		# o Question definitions and their ids while within the ToC.
		# o Section titles.

		if (($i >= $offsets{start_of_toc}) && ($i <= $offsets{end_of_toc}) )
		{
			# $qr_link_name = qr/(.+?)(\d+)\s+(.+]\(#q)(\d+)(.+)/;

			if ($$lines[$i] =~ $qr_link_name) # Sets $1, $2, $3, $4 and $5.
			{
				# Sample link names:
				# o * [102 What is Libmarpa?](#q102)
				#	or
				# o * [155 Where can I find a timeline (history) of parsing?](#q155)
	
				$q_number	= $2;
				$text		= $3;
				$link_number	= $4;

				say "Line: $i. Link name: [$q_number $text](#q$link_number)" if ($$option{report} == 2);

				# Stockpile info for the error reporter.

				$error_parameters{link_number}	= $link_number;
				$error_parameters{q_number}	= $q_number;
				$error_parameters{text}		= $text;

				# Validate that the question text is unique.

				if ($question2link{$text})
				{
					$error_count++;

					report_error(1, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				# Validate that the link number is unique.

				if ($link2question{$link_number})
				{
					$error_count++;

					report_error(2, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				# Validate that the question # matches the link number.

				if ($q_number != $link_number)
				{
					$error_count++;

					report_error(3, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				say "Saving link_number: $link_number => text: $text" if ($$option{report} == 4);

				$link2question{$link_number}	= $text;
				$question2link{$text}		= $link_number;

			}
			elsif ($$lines[$i] =~ $qr_section_name) # Sets $1.
			{
				# Sample section names:
				# o ###About Marpa
				# o ###Resources

				$section_name			= $+;
				$sections_in_toc{$section_name}	= $i;

				say "Testing line: $i. Found section '$section_name' in ToC. Text: $$lines[$i]" if ($$option{report} == 5);
			}
		}
		elsif ($i > $offsets{end_of_toc})
		{
			# Stockpile stuff after the ToC, i.e. while within the Body.

			if ($$lines[$i] =~ $qr_link_target) # Sets $1.
			{
				# Sample link target definitions (2 successive lines):
				# o <a name = 'q102'></a>
				# o 102 What is Libmarpa?
				#	or
				# o <a name = 'q155'></a>
				# o 155 Where can I find a timeline (history) of parsing?

				$link_target			= $1;
				$error_parameters{link_target}	= $link_target;
				$references{$link_target}	= $i;

				say "Testing line: $i. Text: $$lines[$i]"	if ($$option{report} == 3);
				say "Line: $i. Link target: <$link_target>"	if ($$option{report} == 3);
			}

			# Sample link references:
			# o See also <a href='#q6'>Q 6</a>.
			# o See also <a href='#q108'>Q 108</a> and <a href='#q109'>Q 109</a>.

			# 0: "See also <a href='#q"
			# 1: 108
			# 2: "'>Q "
			# 3: 108
			# 4: "<"
			# 5: "/a> and <a href='#q"
			# 6: 109
			# 7: "'>Q "
			# 8: 109
			# 9: "<"
			# Multiple links. i: 246. See also <a href='#q108'>Q 108</a> and <a href='#q109'>Q 109</a>.

			# $qr_link_reference) = qr/(.+?'#q)(\d+)('>Q )(\d+)(<)/;

			@list_of_refs = ($$lines[$i] =~ /$qr_link_reference/g); # Sets $1, $2, $3, $4 and $5.

			for (my $ref = 1; $ref < $#list_of_refs; $ref += 5)
			{
				$link_reference	= $list_of_refs[$ref];
				$link_text	= $list_of_refs[$ref + 2];

				if ($$option{report} == 4)
				{
					say '-------------------------';
					say "Line: $i. token $ref: $link_reference. token @{[$ref + 2]}: $link_text. Line: $$lines[$i]";
					say "ref: $ref. " . Dumper(@list_of_refs);
					say '-------------------------';
				}

				if ($link_reference ne $link_text)
				{
					$error_count++;

					$error_parameters{text} = "$link_reference ne $link_target";

					report_error(8, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				$error_parameters{link_reference}	= $link_reference;
				$references{$link_reference}		= $i;
			}

			if ($$lines[$i] =~ $qr_section_name) # Sets $1.
			{
				# Sample section names:
				# o ###About Marpa
				# o ###Resources

				$section_name				= $+;
				$sections_in_body{$section_name}	= $i;

				say "Testing line: $i. Found section '$section_name' in Body. Text: $$lines[$i]" if ($$option{report} == 5);

				if (! $sections_in_toc{$section_name})
				{
					$section_error = true;

					$error_count++;

					$error_parameters{text} = $section_name;

					#say "Line: $i. Section $section_name not in ToC";

					report_error(5, \%errors, \%error_parameters, \%link2question, \%question2link);
				}
			}
		}
	}

	$error_parameters{i}			= 0;
	$error_parameters{link_number}		= 'EOF';
	$error_parameters{q_number}		= 'EOF';
	$error_parameters{text}			= 'EOF';

	# Validate that in-situ links point to extant targets.

	for $link_reference (sort keys %references)
	{
		$error_parameters{link_reference} = $link_reference;

		say "Testing link reference: $link_reference" if ($$option{report} == 4);

		# Validate that the link target exists.

		if (! $link2question{$link_reference})
		{
			$error_count++;

			say "bad link_reference: $link_reference" if ($$option{report} == 4);

			report_error(4, \%errors, \%error_parameters, \%link2question, \%question2link);
		}
		else
		{
			say "good link2question: $link2question{$link_reference}" if ($$option{report} == 4);
		}
	}

	# Validate that the section names in the Body were present in the ToC.

	for $section_name (sort keys %sections_in_toc)
	{
		$error_parameters{i} = $sections_in_toc{$section_name};

		if (! defined $sections_in_body{$section_name})
		{
			$section_error = true;

			$error_count++;

			$error_parameters{text} = $section_name;

			#say "Line: $error_parameters{i}. Section $section_name not in Body";

			report_error(6, \%errors, \%error_parameters, \%link2question, \%question2link);
		}
	}

	# Validate that the section names in the ToC are in the same order as in the Body.

	if (isFalse($section_error) )
	{
		if (join(', ', sort keys %sections_in_toc) ne join(', ', sort keys %sections_in_body) )
		{
			$error_count++;

			report_error(7, \%errors, \%error_parameters, \%link2question, \%question2link);
		}
	}

	return ($error_count, \%link2question, \%offsets, \%question2link, \%sections_in_body, \%sections_in_toc);

} # End of validate.

# -----------------------------------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option);

if ($option_parser -> getoptions
(
 \%option,
 'help',
 'report:i',	# The : means the option value is optional and here defaults to 0 via the code above.
 'version:s',	# The version # to insert into the output file.
) )
{
	pod2usage(1) if ($option{'help'});

	exit run(\%option);
}
else
{
	pod2usage(2);
}

__END__

=pod

=head1 NAME

preprocess.pl - Validate input (guide/faq.txt) and output new version.

=head1 DESCRIPTION

Validate guide/faq.txt and convert it into guide/faq.new.
Renumber questions sequentially from 1 up.

=head1 SYNOPSIS

preprocess.pl [options]

	Options:
	-help
	-report Integer
	-version d.dd

All switches can be reduced to a single letter.

Exit value: 0 or error count.

=head1 OPTIONS

=over 4

=item -help

Print help and exit.

=item -report Integer

Various numbers print various reports.

=over 4

=item 1

Report Table of Contents stats and lines containing multiple cross-references.

=item 2

Report lines containing link names.

=item 3

Report lines containing link targets.

=item 4

Report lines containing link references.

=item 5

Report section names.

=item 6

Report renumbering of section names.

=item 7

Report lines in ToC containing question names (after renumbering sections).

=item 8

Report lines in Body containing question lines and references (after renumbering sections).

=back

Defaults (0 or no switch): Only minimal stuff and errors.

=item -version d.dd

The version # to insert into the output file.

Defaults to the current version if found or 1.00.

=back

=cut

