my $KATRdir = '/homes/raphael/links/r';

use Text::Diff;
use Unicode::Normalize;

sub height {
	my ($tree) = @_;
	# print "<!-- height [ -->\n";
	my @node = @$tree;
	my $answer = 0;
	while (scalar @node > 1) { # one child
		my $MP = shift @node;
		my $subtree = shift @node;
		my $childHeight = height($subtree) + 1;
		# print "<!-- height of $MP is $childHeight -->\n";
		$answer = $childHeight if $childHeight > $answer;
	}
	# print "<!-- height ] $answer -->\n";
	return($answer);
} # height

sub displayRecursive {
	my ($tree, $first, $parentMP, $topLevel) = @_;
	# convert $tree to HTML.  $first == 1 if this is the first child
	# $topLevel == 1 if no labels have been attached yet
	my @node = @$tree;
	my $height = height($tree);
	# print "<!-- displayRecursive [ $parentMP, height $height, " .
	# 	($topLevel ? 'toplevel ' : '') .
	# 	($first ? 'first ' : '') .
	# 	"-->\n";
	if ($topLevel) {
		if ($first and length($parentMP)) {
			print '<h2>' . ($height >= 4 ? $parentMP : '') . '</h2>';
		}
		if ($height <= 4) {
			print "<table style=\"border-style:solid; border-width:medium;
				border-color:black\">\n";
		}
		printf "<tr><td bgcolor='#AAAAFA'>$parentMP</td></tr>\n%s",
				($height == 0 ? '<tr>' : '')
			if length($parentMP) and $height < 4;
	} # topLevel
	# print "<!-- \n" . Dumper($tree) . "\n-->\n";
	while (scalar @node) { # one child
		if (scalar(@node) == 1) { # leaf
			my $value = shift @node;
			print "<td align='left' bgcolor='#CCCCCC'>$value</td>\n";
		} else { # internal node
			my $MP = shift @node;
			my $subtree = shift @node;
			my $subheight = height($subtree);
			$parentMP = '' unless $first;
			if ($height == 5) {
				# print "<!-- height 5 -->\n";
				displayRecursive($subtree, 1, $MP, 1);
			} elsif ($height == 4) {
				# print "<!-- height 4 -->\n";
				if ($first) {
					print "<tr bgcolor='#FFFFAA'>";
					print "<td align='center' bgcolor='#AAFFAA'>$parentMP</td>";
					showTitle($subtree);
					print "</tr>\n";
				}
				print "<tr>";
				print "<td align='center' valign='middle' bgcolor='#AAAAFF'>$MP</td>\n"
					if $subheight > 2;
				displayRecursive($subtree, 1, $MP, 0);
				print "</tr>\n";
			} elsif ($height == 3) {
				# print "<!-- height 3 -->\n";
				if (!$topLevel) {
					print "<td align='center' valign='middle'><table border='1' width='100%'>\n";
				}
				displayRecursive($subtree, 1, $MP, 0);
				if (!$topLevel) {
					print "</table></td>\n";
				}
			} elsif ($height == 2) {
				# print "<!-- height 2 -->\n";
				if ($first || $topLevel) {
					print "<tr bgcolor='#AAFFAA'>";
					print "<td bgcolor='#FFAAAA'>$parentMP</td>";
					showTitle($subtree);
					print "</tr>\n";
				}
				print "<tr><td align='center' valign='middle' bgcolor='#FFAAFF'>$MP</td>\n";
				displayRecursive($subtree, 1, $MP, 0);
				print "</tr>\n";
			} elsif ($height == 1) {
				# print "<!-- height 1: $MP -->\n";
				displayRecursive($subtree, 1, $MP, 0);
			} else { # greater height
				# print "<!-- height >5: $MP -->\n";
				displayRecursive($subtree, 1, $MP, $topLevel);
			}
		} # internal node
		$first = 0;
	} # one child
	if ($topLevel) {
		print "</tr>" if length($parentMP) and $height < 4;
		print "</table>\n" if ($height <= 4);
	}
	# print "<!-- displayRecursive ] $parentMP -->\n";
} # displayRecursive

sub showTitle {
	my ($tree) = @_;
	my @node = @$tree;
	while (scalar @node) { # one child
		if (scalar(@node) == 1) { # leaf
			return;
		} else { # internal node
			my $MP = shift @node;
			my $subtree = shift @node;
			my $height = height($subtree);
			if ($height == 2) {
				print "<td align='center'>$MP</td>";
			} elsif ($height == 0) {
				print "<td align='center'>$MP</td>";
			} else {
			}
		} # internal node
	} # one child
} # showTitle

sub displayTree {
	my ($head, $tree) = @_;
	# print "<!-- displayTree [ -->\n";
	use utf8;
	# $head =~ s/u(\d+)/chr($1)/eg;
	$head =~ s/u([0-9abcdef]{4})/sprintf('%c',hex($1))/eg;
	print "<a name='$head'></a><h1>$head</h1>\n";
	displayRecursive($tree, 1, '', 1);
	# print "<!-- displayTree ] -->\n";
} # displayTree

sub standardizeText {
	my ($text) = @_;
	$text =~ s/[<>]//g;
	$text =~ s/[ \t]+/ /g;
	$text =~ s/ +$//mg;
	return lc(NFC($text));
} # standardizeText

sub execProgCompare {
	my ($prefix, $compareText) = @_;
	$compareText = standardizeText($compareText);
	# print "comparing against <pre>$compareText</pre><br/>\n";
	my $result = standardizeText(
		decode("utf8", `cd $KATRdir; make -s katr GOAL=$prefix 2>&1`)
	);
	# print "new result <pre>$result</pre><br/>\n";
	my $diff = diff \$result, \$compareText, {CONTEXT=>0, STYLE=>'Unified'};
	$diff =~ s/@@.*//g;
	$diff =~ s/^-/new: /mg;
	$diff =~ s/^\+/old: /mg;
	if ($diff =~ /\w/) {
		print "difference: <pre>$diff</pre><br/>\n";
	} else {
		print "no differences between old and new versions<br/>\n";
	}
} # execProgCompare

sub execProgNoFormat {
	my ($prefix) = @_;
	my $result = decode("utf8", `cd $KATRdir; ~raphael/bin/within 5 make -s katr GOAL=$prefix 2>&1`);
	for my $line (split /\n/, $result) {
		# print "result: [$result]<br/>\n";
		next if $line =~ /all\./;
		chomp $line;
		if ($line =~ /(\S+)\s(\S*) = count (\d+) from (.*)/) {
			my ($node, $path, $count, $from) = ($1, $2, $3, $4);
			print 
				"<span style='color:#FF0000'>$node</span> " .
				"<span style='color:#009900'>&lt;$path&gt;</span> " .
				"<span style='color:#0000FF'>$count occurrence" .
				($count == 1 ? "" : "s") . " from $from</span> " .
				"<br/\>\n";
		} elsif ($line =~ /(\S+)\s+(\S+)\s+(.*)/) {
			my ($lexeme, $MPS, $surface) = ($1, $2, $3);
			# $lexeme =~ s/u(\d+)/chr($1)/eg; # undo conversions to ascii
			$lexeme =~ s/u([0-9abcdef]{4})/sprintf('%c',hex($1))/eg;
			print
				"<span style='color:#FF0000'>$lexeme</span> " .
				"<span style='color:#009900'>&lt;$MPS&gt;</span> " .
				"<span style='color:#0000FF'>$surface</span> " .
				"<br/\>\n";
		}
	} # each line
} # execProgNoFormat

sub execProg {
	my ($prefix) = @_;
	my $result = decode("utf8", `cd $KATRdir; ~raphael/bin/within 5 make -s katr GOAL=$prefix`);
	# print "<pre>$result</pre>";
	# system "cp $prefix.katr /tmp/raphaelSave"; # for debugging
	# unlink "/tmp/raphaelSave";
	for my $fileName (<prefix*>) {
		unlink Untaint($fileName);
	}
	$result =~ s/\| \?- all\.\n//;
	# $result =~ s/((\w+,)+\w+)/<span style="color:#FF0000">$1<\/span>/mg;
	# $result =~ s/^(\w+)\s+((\w+,)+\w+)\s+(.*)/
	# my $length = 1; # greatest number of MPSs in any line
	# while ($result =~ /(,\w+){$length}/) {
	# 	$length += 1;
	# }
	# my @prevMPS = ();
	my $tree = [];
		# internal nodes are [MP, subtree, MP, subtree, ...]
	my $prevHead = '';
	my @lexemes = ();
	for my $line (split /\n/, $result) { # discover all the lexemes
		$line =~ /^(\w+|)\s+([\w,]+)\s+(.*)/;
		my $head = $1;
		next unless defined $head;
		$head =~ s/_/, /g;
		next if $head eq $prevHead;
		my $printableHead = $head;
		# $printableHead =~ s/u(\d+)/chr($1)/eg;
		$printableHead =~ s/u([0-9abcdef]{4})/sprintf('%c',hex($1))/eg;
		push @lexemes, "<a href='#$printableHead'>$printableHead</a>";
		$prevHead = $head;
	}
	print "" . join(" | ", @lexemes) . "\n" unless @lexemes < 2;
	$prevHead = '';
	print "\n";
	for my $line (split /\n/, $result) {
		$line =~ /^(\w+|)\s+([\w,]+)\s+(.*)/;
		my ($head, $MPSstring, $value) = ($1, $2, $3);
		# print "<br/>value is: $value\n";
		next unless defined $value;
		$head =~ s/_/, /g;
		if ($head ne $prevHead) {
			if ($prevHead ne '') { # finished a tree
				# print "Tree for $prevHead: " . Dumper($tree) . "\n";
				displayTree($prevHead, $tree);
			}
			$prevHead = $head;
			$tree = [];
		} # new head word
		$MPSstring =~ s/([A-Z])/" " . lc($1)/eg;
		my @MPS = split(/,/, $MPSstring);
		$value =~ s/ *$//; # strip blanks
		# print "Inserting $value for " . join(', ', @MPS) . "\n";
		$tree = insertValue($tree, $value, @MPS);
		# print "So far for $head: " . Dumper($tree) . "\n";
		# @prevMPS = @MPS;
	} # each line
	displayTree($prevHead, $tree);
} # execProg

sub insertValue {
	my ($tree, $value, @MPS) = @_;
	my @node = @$tree;
	if (scalar(@MPS) == 0) {
		return [$value];
	}
	my $MP = shift @MPS;
	if (scalar(@node) == 1) { # no children
		# print STDERR "no children; adding $MP\n"; # debug
		push @node, $MP;
		push @node, insertValue([], $value, @MPS);
	} elsif (defined($node[-2]) and $node[-2] eq $MP) { # continuing last child
		# print STDERR "continuing child $MP\n"; # debug
		$node[-1] = insertValue($node[-1], $value, @MPS);
	} else { # new child
		# print STDERR "new child for $MP\n"; # debug
		push @node, $MP;
		push @node, insertValue([], $value, @MPS);
	}
	return \@node;
} # insertValue

1;
