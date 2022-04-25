#!/usr/bin/perl -wT

# datr.cgi: converts DATR theory to KATR and run it.

# Raphael Finkel 2/2011

use strict;
use utf8;
use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);
use Encode;

require './showKATR.pm';

# variables
my $noFormat; # whether to call the fancy formatter

sub init {
    $ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin:/usr/local/gnu/bin';
	binmode STDOUT, ":utf8";
	binmode STDERR, ":utf8";
	$noFormat = defined(param('noFormat'));
	$noFormat = 0 unless defined($noFormat);
	print header(-charset=>'UTF-8', -expires=>'-1d',
        '-Content-Script-Type'=>'text/javascript',
        '-Content-Style-Type'=>'text/css',
        );
	my $analytics = `cat analytics.txt`;
	# $analytics = ''; # suppress
	my $starter = start_html(
		-encoding=>'UTF-8',
		-title=>'DATR',
		-style=>{'src'=>'/~raphael/dictstyle.css'},
		-head=>Link({-rel=>'icon', -href=>'kentucky_wildcats.ico'}),
		# -dtd=>'',
		-script=>"
			// <--

			// http://www.codeproject.com/KB/scripting/stringbuilder.aspx
			function StringBuilder(value) {
				this.strings = new Array('');
				this.append(value);
			} // StringBuilder

			StringBuilder.prototype.append = function (value) {
				if (value) {
					this.strings.push(value);
				}
			} // append

			StringBuilder.prototype.toString = function () {
				return this.strings.join('');
			} // toString
	
			var fileCount = 1;
			function newNumFiles() {
				fileCount = document.getElementById('numFiles').value;
				var sb = new StringBuilder('');
				// alert('changing to ' + fileCount);
				for (var which = 1; which <= fileCount; which += 1) {
					sb.append('File ');
					sb.append(which);
					sb.append(':  <input type=\\'file\\' name=\\'file');
					sb.append(which);
					sb.append('\\' title=\\'File ');
					sb.append(which);
					sb.append('\\' /><br/>\\n');
				} // each file
				document.getElementById('theFiles').innerHTML =
					sb.toString();
			} // newNumFiles
	
			var pasteCount = 1;
			function newNumPastes() {
				pasteCount = document.getElementById('numPastes').value;
				var sb = new StringBuilder('');
				// alert('changing to ' + pasteCount);
				for (var which = 1; which <= pasteCount; which += 1) {
					sb.append('<textarea name=\\'text');
					sb.append(which);
					sb.append('\\' rows=\\'5\\' cols=\\'80\\' ' +
						'title=\\'text input\\'><\\/textarea><br\/>');
				} // each paste
				document.getElementById('thePastes').innerHTML =
					sb.toString();
			} // newNumFiles
		$analytics
		// -->
		",
	);
	$starter =~ s/<!DOCTYPE html.*?>/<!DOCTYPE html>\n/s; # HTML5
	print $starter;
	print `cat boilerplate.txt`;
	$0 =~ /([^\/]+)$/;
	my $progName = $1;
	print "
	<h1>DATR evaluator</h1>
	<form method='post' enctype='multipart/form-data'
		accept-charset='UTF-8'>
		You can paste your theory here.
		Number of parts to paste:
			<input type='number' name='numPastes' style='width:2em'
			min='1' max='9' value='1' id='numPastes' onchange='newNumPastes();'/>
		<br/>
		<div id='thePastes'>
		<textarea name='text1' rows='5' cols='80' title='text input'></textarea>
		</div>
		<br/>
		<input type='checkbox' name='noFormat' " .
			($noFormat ? "checked='CHECKED'" : '') .  ">
			List results instead of fancy formatting
		<br/>
		<input type='submit' value='submit text'/>
		<input type='reset' value='clear'/><br/>
	</form>
	<hr/>
		or upload your DATR theory here.<br/>
	<form method='post' enctype='multipart/form-data'
		accept-charset='UTF-8'>
		Number of files in the theory:
			<input type='number' name='numFiles' style='width:2em'
			min='1' max='9' value='1' id='numFiles' onchange='newNumFiles();'/>
		<br/>
		<span id='theFiles'>
			File: <input type='file' name='file1' title='File' />
			<br/>
		</span>
		<input type='checkbox' name='noFormat' " .
			($noFormat ? "checked='CHECKED'" : '') .  ">
			List results instead of fancy formatting
		<br/>
		<input type='submit' value='submit'/>
		<input type='reset' value='clear' />
	</form>
";
} # init

sub addShow {
	my ($region) = @_;
	my @answer;
	$region =~ s/\n/ /g; # remove newlines
	for my $line (split /(?=<)/, $region) {
		next unless $line =~ /</;
		push @answer, "#show $line .";
	} # each line
	return join("\n", @answer);
} # addShow

sub addHide {
	my ($toHide) = @_;
	$toHide =~ s/\n/ /g;
	return "#hide $toHide .\n";
} # addHide

sub toHTML { # escape non-HTML characters
	my ($text) = @_;
	return '' unless defined($text);
	$text =~ s/</\&lt;/g;
	$text =~ s/>/\&gt;/g;
	return $text;
} # toHTML

my @coded; # how it was encoded

sub toUTF8 {
	my ($string) = @_;
	$string //= '   ';
	my ($success, $decoded);
	# first try BOM (byte-order mark)
	for my $BOM (
		[255.254.0.0, 'UTF-32LE'],
		[239.187.191, 'utf8'],
		[v254.255, 'UTF-16BE'], # could fail for 3% of UCS-2BE
		[v254.255, 'UCS-2BE'],
		[v255.254, 'UTF-16LE'], # could fail for 3% of UCS-2LE
		[v255.254, 'UCS-2LE'],
		[0.0.254.255, 'UTF-32BE'],
		[43.47.118, 'UTF-7'],
	) {
		my ($chars, $fromCode) = @$BOM;
		my $length = length $chars;
		if (substr($string,0,$length) eq $chars) {
			$success =
				eval{$decoded = decode($fromCode, $string, Encode::FB_CROAK);};
			if (defined($success)) {
				# print "BOM determined $fromCode<br/>\n";
				push @coded, $fromCode;
				last;
			}
		}
	} # all BOM possibilities
	if (!defined($success)) { # look for nulls in opportune places
		for my $nullPoint ([2, 'UTF-16BE'], [3, 'UTF-16LE']) {
			my ($place, $fromCode) = @$nullPoint;
			if (substr($string,$place,1) eq chr(0)) {
				$success =
					eval{$decoded = decode($fromCode, $string, Encode::FB_CROAK);};
				if (defined($success)) {
					# print "null point determined $fromCode<br/>\n";
					push @coded, $fromCode;
					last;
				}
			} # found a propitious null
		} # each null point
	} # look for nulls
	if (!defined($success)) { # no luck.  Just try last-ditch possibilities
		for my $fromCode ('utf8', 'ascii') {
			$success =
				eval{$decoded = decode($fromCode, $string, Encode::FB_CROAK);};
			if (defined($success)) {
				push @coded, $fromCode;
				last;
			}
		} # each $fromCode
	} # last-ditch
	if (defined($success)){
		return($decoded);
	} else {
		push @coded, "unknown encoding";
		return("");
	}
} # toUTF8

sub doIt {
	my $text;
	if (defined(param('immediateFile'))) {
		$/ = undef; # read file all at one gulp
		my $Infile = param('immediateFile');
		open INFILE, $Infile;
		binmode INFILE, ":utf8";
		$text = <INFILE>;
	} elsif (defined(param('text1'))) {
		$text = '';
		my $index = 1;
		while (defined(param('text' . $index))) {
			$text .= decode_utf8(scalar param('text' . $index));
			$index += 1;
		}
	} elsif (!defined(param('file1'))) { # debug
		# return;
		open IN, "/tmp/a.dtr" or finalize(); 
		binmode IN, ":raw";	
		$/ = undef; # read file all at one gulp
		$text = toUTF8(<IN>);
		close IN;
	} else {
		# return unless defined(param('file'));
		# return if (param('file') eq ""); # nothing to compute
		my $numFiles = param('numFiles');
		$text = '';
		for my $which (1 .. $numFiles) {
			my $InFile = param("file$which");
			binmode $InFile, ":raw";
			# binmode $InFile, ":encoding(utf16)";	
			$/ = undef; # read file all at one gulp
			$text .= toUTF8(<$InFile>);
			close $InFile;
		} # each input file from form
		print "<span style='color: #000088;'>The " .
			($numFiles > 1 ? "files are" : "file is") .
			" encoded as: " . join(', ', @coded) . ".</span><br/>\n";
	} # get text from form
	$text =~ s///g; # prefer Unix style
	$text =~ s/%.*//mg; # remove comments
	$text =~ s/[“”„‟❝❞〝〞«»]/"/g; # normalize quote-like characters
	$text =~ s/^#load.*/% #load/mg; # remove "load" directives
	$text =~ s/=(.*)\./=$1\n\t./g; # move misplaced final dot
	$text =~ s/#\s*show([^\.]*?\.)/addShow($1)/egs; # fix "#show" lines
	$text =~ s/#\s*hide([^\.]*?)\./addHide($1)/egs; # fix "#hide" lines
	$text =~ s/\.\n\s+/\.\n/g;
	return unless $text =~ /\w/;
	# print "the theory is:<br/><pre>" . toHTML($text) . "</pre><br/>\n";
	my $prefix = "/tmp/datr$$";
	my $fileName = "$prefix.katr";
	open KATR, ">$fileName" or die("cannot write to $fileName\n");
	binmode KATR, ":utf8";
	print KATR $text;
	close KATR;
	# print "look at $prefix.katr\n"; exit(0); # debug
	if ($noFormat) {
		execProgNoFormat($prefix);
	} else {
		execProg($prefix);
	}
	unlink "$prefix.katr";
	unlink "$prefix.katr.pro";
} # doIt

sub finalize {
	print end_html(), "\n";
	exit(0); # in case called because of error
} # finalize

sub Untaint {
	my ($what) = @_;
	$what =~ s/[&*()`\$;|"']//g; # remove suspicious characters
	$what =~ /(.*)/; # untaint
	return($1);
} # Untaint

init();
doIt();
finalize();
