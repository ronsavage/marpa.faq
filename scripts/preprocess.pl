#!/usr/bin/env perl

use 5.018;

use File::Slurper qw/read_lines write_text/;

use Getopt::Long;

use Pod::Usage;

use Syntax::Keyword::Match;

# ------------------------------------------------

sub renumber
{
	my($option) = @_;

} # End of renumber.

# ------------------------------------------------

sub report_error
{
	my($error_number, $errors, $error_parameters, $link2question, $question2link) = @_;

	say "Error #: $error_number. $$errors{$error_number}";

	# Test error number because some info is not available when it's > 3.

	my($msg);

	if ($error_number <= 3)
	{
		$msg = "Line: $$error_parameters{i}. Q: <$$error_parameters{q_number}>. "
			. "Link: <$$error_parameters{link_number}>. <$$error_parameters{text}>";
	}
	else
	{
		$msg = "Line: $$error_parameters{i}. Link reference: $$error_parameters{link_reference}";
	}

	match ($error_number : ==)
	{
		case(1) {say "$msg. Other link: $$question2link{$$error_parameters{text} }"}
		case(2) {say "$msg. Other link: $$link2question{$$error_parameters{text} }"}
		case(3) {say $msg}
		case(4) {say $msg}
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

	say "Processing: $in_file_name. Line count: @{[$#lines + 1]}. Output: $out_file_name";

	my(%errors, %error_parameters, %link2question, @list_of_refs, %offsets, %question2link, %references);
	my($link_number, $link_reference, $q_number, $text);

	$errors{1}		= 'Duplicate question text';
	$errors{2}		= 'Duplicate link number';
	$errors{3}		= 'Mismatch between question number and link number';
	$errors{4}		= 'Link points to non-existant target';
	my($qr_link_name)	= qr/\[(\d+)\s+([^]]+)\]\(#q(\d+)\)/;
	my($qr_link_reference)	= qr/href\s*=\s*'#q(\d+)'/;
	my($qr_link_target)	= qr/a\s+name\s*=\s*'q(\d+)'><\/a>/;
	$offsets{start_of_toc}	= 99999;
	$offsets{end_of_toc}	= 99999;

	for my $i (0 .. $#lines)
	{
		$error_parameters{i} = $i;

		# Find start and end of TOC.

		if ($lines[$i] eq '##Table of Contents grouped by Topic')
		{
			$offsets{start_of_toc} = $i;

			say "Start of TOC at line $i" if ($$option{report} == 1);
		}
		elsif ($lines[$i] eq '##Answers grouped by Topic')
		{
			$offsets{end_of_toc} = $i;

			say "End of TOC @ at line $i" if ($$option{report} == 1);
		}
		
		# Stockpile Question definitions and their ids while within the ToC.

		if ( ($i >= $offsets{start_of_toc}) && ($i <= $offsets{end_of_toc}) )
		{
			# Sample link names:
			# * [102 What is Libmarpa?](#q102)
			# or
			# * [155 Where can I find a timeline (history) of parsing?](#q155)

			if ($lines[$i] =~ $qr_link_name)
			{
				$q_number	= $1;
				$text		= $2;
				$link_number	= $3;

				say "(name) Line: $i. Text: $lines[$i]" if ($$option{report} == 2);

				# Stockpile info for the error reporter.

				$error_parameters{link_number}	= $link_number;
				$error_parameters{q_number}	= $q_number;
				$error_parameters{text}		= $text;

				# Validate that the question text is unique.

				if ($question2link{$text})
				{
					report_error(1, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				# Validate that the link number is unique.

				if ($link2question{$link_number})
				{
					report_error(2, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				# Validate that the question # matches the link number.

				if ($q_number != $link_number)
				{
					report_error(3, \%errors, \%error_parameters, \%link2question, \%question2link);
				}

				$link2question{$link_number}	= $text;
				$question2link{$text}		= $link_number;

			}
		}
		elsif ($i > $offsets{end_of_toc})
		{
			# Sample link target definitions:
			# <a name = 'q102'></a>
			# 102 What is Libmarpa?
			# or
			# <a name = 'q155'></a>
			# 155 Where can I find a timeline (history) of parsing?

			if ($lines[$i] =~ $qr_link_target)
			{
				$link_reference				= $1;
				$error_parameters{link_reference}	= $link_reference;
				$references{$link_reference}		= $i;

				say "Testing Line: $i. Text: $lines[$i]" if ($$option{report} == 3);
				say "(targ) Line: $i. Ref: <$link_reference>. Text: $lines[$i]" if ($$option{report} == 3);
			}

			# Sample link references:
			# See also <a href='#q6'>Q 6</a>.
			# See also <a href='#q112'>Q 112</a> and <a href='#q114'>Q 114</a>.

			@list_of_refs = ($lines[$i] =~ /$qr_link_reference/g);

			if ($#list_of_refs == 1)
			{
				say "Multiple links. i: $i. $lines[$i]";
			}

			if ($#list_of_refs >= 0)
			{
				$link_reference				= $1;
				$error_parameters{link_reference}	= $link_reference;
				$references{$link_reference}		= $i;

				say "Testing Line: $i. Text: $lines[$i]" if ($$option{report} == 4);
				say "(ref.) Line: $i. Ref: <$link_reference>. Text: $lines[$i]" if ($$option{report} == 4);
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

		say "Testing Link reference: $link_reference" if ($$option{report} == 4);

		# Validate that the link target exists.

		if (! $link2question{$link_reference})
		{
			say "bad  link_reference: $link_reference" if ($$option{report} == 4);

			report_error(4, \%errors, \%error_parameters, \%link2question, \%question2link);
		}
		else
		{
			say "good link2question: $link2question{$link_reference}" if ($$option{report} == 4);
		}
	}

	write_text($out_file_name, join("\n", @lines) . "\n");

	return 0;

} # End of run.

# -----------------------------------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option);

if ($option_parser -> getoptions
(
 \%option,
 'help',
 'report:i', # The : means the option value is optional and here defaults to 0 via the code above.
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
	-report 0|1|2|3|4

All switches can be reduced to a single letter.

Exit value: 0.

=head1 OPTIONS

=over 4

=item -help

Print help and exit.

=item -report Integer

Various numbers print various reports. See above for range of integers.

Defaults (0 or no switch): Only minimal stuff and errors.

=back

=cut

