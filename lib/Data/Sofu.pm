###############################################################################
#sofu.pm
#Last Change: 2005-04-14
#Copyright (c) 2004 Marc-Seabstian "Maluku" Lucksch
#Version 0.21
####################
#This file is part of the sofu.pm project, a parser library for an all-purpose
#ASCII file format. More information can be found on the project web site
#at http://sofu.sourceforge.net/ .
#
#sofu.pm is published under the terms of the MIT license, which basically means
#"Do with it whatever you want". For more information, see the license.txt
#file that should be enclosed with libsofu distributions. A copy of the license
#is (at the time of this writing) also available at
#http://www.opensource.org/licenses/mit-license.php .
###############################################################################
package Data::Sofu;
use strict;
use vars qw($VERSION);
$VERSION="0.24";
sub new {
	my $self={};
	shift;
	$$self{CurFile}="";
	$$self{Counter}=0;
	$$self{WARN}=1;
	$$self{Debug}=0;
	$$self{Ref}=[];
	$$self{Indent}="";
	$self->{String}=0;
	$self->{Escape}=0;
	$$self{SetIndent}="";
	$$self{READLINE}="";
	$self->{COUNT}=0;
	$$self{Libsofucompat}=0;
	$$self{Commentary}={};
	$$self{PreserveCommentary}=1;
	$$self{TREE}="";
	$self->{COMMENT}=[];
	bless $self;
	return $self;
}
sub noComments {
	my $self=shift;
	$$self{PreserveCommentary}=0;
}
sub comment {
	my $self=shift;
	my $data=undef;
	if ($_[0]) {
		if (ref $_[0] eq "HASH") {
			$data=shift;
		}
		else {	
			$data={@_};
		}
	}
	$$self{Commentary}=$data if $data;;
	return $self->{Commentary};
}
sub setIndent {
	my $self=shift;
	local $_;
	$$self{SetIndent}=shift;
}
sub setWarnings {
	my $self=shift;
	local $_;
	$$self{WARN}=shift;
}
sub allWarn {
	my $self=shift;
	local $_;
	$$self{WARN}=1;
}
sub noWarn {
	my $self=shift;
	local $_;
	$$self{WARN}=0;
}
sub iKnowWhatIAmDoing {
	my $self=shift;
	local $_;
	$$self{WARN}=0;
}
sub iDontKnowWhatIAmDoing {
	my $self=shift;
	local $_;
	$$self{WARN}=1;
}
sub commentary {
	my $self=shift;
	return "" unless $self->{PreserveCommentary};
	my $tree=$self->{TREE};
	$tree="=" unless $tree;
	if ($self->{Commentary}->{$tree}) {
		my $res;
		$res=" " if $self->{TREE};
		foreach (@{$self->{Commentary}->{$tree}}) {
		#	print ">>$_<<\n";
			$res.="\n" if $res and $res ne " ";
			$res.="# $_";
		}
		return $res;
	}
	return "";
}
sub writeList {
	my $self=shift;
	local $_;
	my $deep=shift;
	my $ref=shift;
	my $res="";
	my $tree=$self->{TREE};
	foreach (@{$$self{Ref}}) {
		$res.="\"\"" and $self->warn("Cross-reference ignored") and return 0 if $_ == $ref;
	}
	push @{$$self{Ref}},$ref;
	$res.="(".$self->commentary."\n";
	my $i=0;
	foreach my $r (@{$ref}) {
		$self->{TREE}=$tree."->$i";
		if (not ref($r)) {
			$res.=$$self{Indent} x $deep."\"".$self->escape($r)."\"".$self->commentary."\n";
		}
		elsif (ref $r eq "HASH") {
			$res.=$$self{Indent} x $deep;
			$res.=$self->writeMap($deep+1,$r);
		}
		elsif (ref $r eq "ARRAY") {
			$res.=$$self{Indent} x $deep;
			$res.=$self->writeList($deep+1,$r);
		}
		else {
			$self->warn("Non sofu reference");
		}
		$i++;
		
	}
	return $res.$$self{Indent} x --$deep.")\n";
}
sub writeMap {
	my $self=shift;
	local $_;
	my $deep=shift;
	my $ref=shift;
	my $tree=$self->{TREE};
	my $res="";
	foreach (@{$$self{Ref}}) {
		$res.="\"\"" and $self->warn("Cross-reference ignored") and return $res if $_ == $ref;
	}
	push @{$$self{Ref}},$ref;
	$res.="{".$self->commentary."\n" if $deep or not $$self{Libsofucompat};
	foreach (sort keys %{$ref}) {
		$self->{TREE}=$tree."->$_";
		unless (ref $$ref{$_}) {
			$res.=$$self{Indent} x $deep."$_ = \"".$self->escape($$ref{$_})."\"".$self->commentary."\n";
		}
		elsif (ref $$ref{$_} eq "HASH") {
			$res.=$$self{Indent} x $deep."$_ = ";
			$res.=$self->writeMap($deep+1,$$ref{$_});
		}
		elsif (ref $$ref{$_} eq "ARRAY") {
			$res.=$$self{Indent} x $deep."$_ = ";
			$res.=$self->writeList($deep+1,$$ref{$_});
		}
		else {
			$self->warn("non Sofu reference");
		}
		
	}
	$res.=$$self{Indent} x --$deep."}\n" if $deep or not $$self{Libsofucompat};
	return $res;
}
sub write {
	my $self=shift;
	local $_;
	my $file=shift;
	my $fh;
	$$self{TREE}="";
	unless (ref $file) {
		$$self{CurFile}=$file;
		open $fh,">",$$self{CurFile} or die "Sofu error open: $$self{CurFile} file: $!";
	}
	elsif (ref $file eq "GLOB") {
		$$self{CurFile}="FileHandle";
		$fh=$file;
	}
	else {
		$self->warn("The argument to read or write has to be a filehandle");
		return;
	}
	my $ref=shift;
	$self->{Commentary}={};
	$self->comment(@_);
	$$self{Indent}="\t" unless $$self{SetIndent};
	$$self{Libsofucompat}=1;
	print $fh $self->commentary,"\n";
	unless (ref $ref) {
		print $fh "Value=".$self->escape($ref);
	}
	elsif (ref $ref eq "HASH") {
		print $fh $self->writeMap(0,$ref);
	}
	elsif (ref $ref eq "ARRAY") {
		print $fh "Value=".$self->writeList(0,$ref);
	}
	else {
		$self->warn("non Sofu reference");
		return "";
	}
	$$self{Libsofucompat}=0;
	$$self{Indent}="";
	close $fh if ref $file;
	$$self{CurFile}="";
	return 1;
}


sub read {
	my $self=shift;
	local $_;
	my $file=shift;
	my $fh;
	$$self{TREE}="";
	$self->{Commentary}={};
	unless (ref $file) {
		$$self{CurFile}=$file;
		open $fh,$$self{CurFile} or die "Sofu error open: $$self{CurFile} file: $!";
	}
	elsif (ref $file eq "GLOB") {
		$$self{CurFile}="FileHandle";
		$fh=$file;
	}
	else {
		$self->warn("The argument to read or write has to be a filehandle");
		return;
	}
	my $text=do {local $/,<$fh>};
	close $fh if ref $file;
	$$self{CurFile}="";
	return %{$self->unpack($text)};
}
sub pack {
	my $self=shift;
	my $ref=shift;
	local $_;
	$self->{Commentary}={};
	$self->comment(@_);
	$$self{TREE}="";
	@{$$self{Ref}}=();
	$$self{Indent}=$$self{SetIndent} if $$self{SetIndent};
	$$self{Counter}=0;
	unless (ref $ref) {
		return $self->commentary.$self->escape($ref);
	}
	elsif (ref $ref eq "HASH") {
		return $self->commentary.$self->writeMap(0,$ref);
	}
	elsif (ref $ref eq "ARRAY") {
		return $self->commentary.$self->writeList(0,$ref);
	}
	else {
		$self->warn("non Sofu reference");
		return "";
	}
}
sub unpack($) {
	my $self=shift;
	local $_;
	$$self{TREE}="";
	$$self{Counter}=0;
	($self->{Escape},$self->{String},$self->{COUNT})=(0,0,0);
	$$self{Line}=1;
	$$self{READLINE}=shift()."\n";
	$$self{LENGTH}=length $$self{READLINE};
	$self->{Commentary}={};
	my $c;
	1 while ($c=$self->get() and $c =~ m/\s/);
	if ($c eq "{") {
		my %result=$self->parsMap;
		1 while ($c=$self->get() and $c =~ m/\s/);
		if ($c=$self->get()) {
			$self->warn("Trailing Characters: $c");
		}
		return {%result};
	}
	elsif ($c eq "(") {
		my @result=$self->parsList;
		1 while ($c=$self->get() and $c =~ m/\s/);
		if ($c=$self->get()) {
			$self->warn("Trailing Characters: $c");
		}
		return [@result];
		
	}
	elsif ($c eq "\"") {
		my @result=$self->parsValue;
		1 while ($c=$self->get() and $c =~ m/\s/);
		if ($c=$self->get()) {
			$self->warn("Trailing Characters: $c");
		}
		return [@result];
	}
	elsif ($c!~m/[\=\"\}\{\(\)\s\n]/) {
		$$self{Ret}=$c;
		my %result=$self->parsMap;
		1 while ($c=$self->get() and $c =~ m/\s/);
		if ($c=$self->get()) {
			$self->warn("Trailing Characters: $c");
		}
		return {%result};
	}
	else {
		$self->warn("Nothing to unpack: $c");
		return 0;
	}
}
sub get() {
	my $self=shift;
	local $_;
	if ($$self{Ret}) {
		my $ch=substr($$self{Ret},0,1,"");
		return $ch;
	}
	return shift if @_ and $_[0] and $_[0]!="";
	$self->{LENGTH}=length $$self{READLINE} unless $self->{LENGTH};
	return undef if $self->{COUNT}>=$self->{LENGTH};
	my $c=substr($$self{READLINE},$self->{COUNT}++,1);
	#print "DEBUG: $self->{COUNT}=$c\n";
	if ($c eq "\"") {
		$self->{String}=!$self->{String} unless $self->{Escape};
	}
	if ($c eq "\\") {
		$self->{Escape}=!$self->{Escape};
	}
	else {
		$self->{Escape}=0;
	}
	if ($c eq "#" and not $self->{String} and not $self->{Escape}){
		my $i=index($$self{READLINE},"\n",$self->{COUNT});
		push @{$self->{COMMENT}},substr($$self{READLINE},$self->{COUNT},$i-$self->{COUNT});
		#print "DEBUG JUMPING FROM $self->{COUNT} to INDEX=$i";
		$self->{COUNT}=$i;
		$c="\n";
	}	
	++$$self{Counter};
	if ($c and $c eq "\n") {
		$$self{Counter}=0;
		$$self{Line}++;
	}
	
	print "END" if not defined $c and $$self{Debug} ;
	return $c;
}
sub storeComment {
	my $self=shift;
	my $tree=$self->{TREE};
	$tree="=" unless $tree;
	#print "DEBUG: $tree, @{$self->{COMMENT}} , ".join(" | ",caller())."\n";
	push @{$self->{Commentary}->{$tree}},@{$self->{COMMENT}} if @{$self->{COMMENT}};
	$self->{COMMENT}=[];
}
sub warn {
	my $self=shift;
	local $_;
	warn "Sofu warning: \"".shift(@_)."\" File: $$self{CurFile}, Line : $$self{Line}, Char : $$self{Counter},  Caller:".join(" ",caller);
	1;
}
sub escape {
	shift;
	my $text=shift;
	$text=~s/\\/\\\\/g;
	$text=~s/\n/\\n/g;
	$text=~s/\r/\\r/g;
	$text=~s/\"/\\\"/g;
	return $text;
}
sub deescape {
	my $self=shift;
	local $_;
	my $text;
	my @text=split//,shift;
	my $char;
	my $escape=0;
	while (defined(my $char=shift @text)) {
		if ($char eq "\\") {
			$text.="\\" if $escape;
			$escape=!$escape;
		}
		else {
			if ($escape) {
				if (lc($char) eq "n") {
					$text.="\n";
				}
				elsif (lc($char) eq "r") {
					$text.="\r";
				}
				elsif (lc($char) eq "\"") {
					$text.="\"";
				}
				else {
					$self->warn("Deescape: Can't deescape: \\$char");
				}
				$escape=0;
			}
			else {
				$text.=$char;
			}
		}
	}
	return $text;
}
sub parsMap {
	my $self=shift;
	local $_;
	my %result;
	my $comp="";
	my $eq=0;
	my $char;
	my $tree=$self->{TREE};
	while (defined($char=$self->get())) {
		print "ParsCompos  $char\n" if $$self{Debug};
		if ($char!~m/[\=\"\}\{\(\)\s\n]/s) {
			if ($eq) {
				$self->storeComment;
				$self->{TREE}=$tree."->".$comp;
				#print ">> > >> > > > > DEBUG: tree=$self->{TREE}\n";
				$result{$comp}=$self->getSingleValue($char);
				$comp="";
				$eq=0;
			}
			else {
				$comp.=$char;
			}
		}
		elsif ($char eq "=") {
			$self->warn("MapEntry unnamed!") if ($comp eq "");
			$self->storeComment;
			$self->{TREE}=$tree."->".$comp;
			$eq=1;
		}
		elsif ($char eq "{") {
			$self->warn("Missing \"=\"!") unless $eq;
			$self->warn("MapEntry unnamed!") if ($comp eq "");
			$self->storeComment;
			$self->{TREE}=$tree."->".$comp;
			my %res=$self->parsMap();
			$result{$comp} = {%res};
			$comp="";
			$eq=0;
		}
		elsif ($char eq "}") {
			$self->storeComment;
			$self->{TREE}=$tree;
			return %result;
		}
		elsif ($char eq "\"") {
			if (not $eq) {
				return $self->parsValue();
			}
			$self->storeComment;
			$self->{TREE}=$tree."->".$comp;
			#print ">>>>>>>>>>>>>>>>>>>>>>>>DEBUG: tree=$self->{TREE}\n";
			$self->warn("Missing \"=\"!") unless $eq;
			$self->warn("MapEntry unnamed!") if ($comp eq "");
			
			$result{$comp}=$self->parsValue();
			$comp="";
			$eq=0;
		}
		elsif ($char eq "(") {
			if (not $eq) {
				return $self->parsList();
			}					
			$self->warn("Missing \"=\"!") unless $eq;
			$self->warn("MapEntry unnamed!") if ($comp eq "");
			$self->storeComment;
			$self->{TREE}=$tree."->".$comp;
			my @res=$self->parsList();
			$result{$comp} = [@res];
			$comp="";
			$eq=0;
		}
		elsif ($char eq ")") {
			$self->warn("What's a \"$char\" doing here?");
		}
	}
	return %result;
}
sub parsValue {
	my $self=shift;
	local $_;
	my @result;
	my $cur="";
	my $in=1;
	my $escape=0;
	my $char;
	my $i=0;
	my $tree=$self->{TREE};
	$self->storeComment;
	$self->{TREE}=$tree."->0";
	while (defined($char=$self->get())) {
	print "ParsValue  $char\n" if $$self{Debug};
		if ($in) {
			if ($char eq "\"") {
				if ($escape) {
					$escape=0;
					$cur.=$char;
				}
				else {
					push @result,$self->deescape($cur);
					$self->storeComment;
					$self->{TREE}=$tree."->".$i++;
					$cur="";
					$in=0;
				}
			}
			elsif ($char eq "\\") {
				if ($escape) {
					$escape=0;
				}
				else {
					$escape=1;
				}
				$cur.=$char;
			}
			else {
				$escape=0;
				$cur.=$char;
			}

		}
		else {
			if ($char!~m/[\=\"\}\{\(\)\s\n]/s) {
				$$self{Ret}=$char;
				if (@result>2) {
					$self->{TREE}=$tree."->$#result";
					$self->storeComment;
					return [@result]
				}
				elsif (@result) {
					$self->{TREE}=$tree;
					$self->storeComment;
					return shift @result;
				}
				else { #This can't happen
					return undef;
				}
			}
			elsif ($char eq "=") {
				$self->warn("What's a \"$char\" doing here?");
			}
			elsif ($char eq "\"") {
				$in=1;
			}
			elsif ($char eq "{") {
				$self->storeComment;
				$self->{TREE}=$tree."->".++$i;
				my %res=$self->parsMap();
				push @result,{%res};
			}
			elsif ($char=~m/[\}\)]/) {
				$$self{Ret}=$char;
				if ($cur ne "") {
					if (@result) {
						$self->{TREE}=$tree."->".$#result+1;
						$self->storeComment;
						return [@result,$cur]
					}
					else { 
						$self->{TREE}=$tree;
						$self->storeComment;
						return $cur;
					}
				}
				else {
					if (@result>2) {
						$self->{TREE}=$tree."->$#result";
						$self->storeComment;
						return [@result]
					}
					elsif (@result) {
						$self->{TREE}=$tree;
						$self->storeComment;
						return shift @result;
					}
					else {
						return $cur;
					}
				}
			}
			elsif ($char eq "(") {
				$self->storeComment;
				$self->{TREE}=$tree."->".++$i;
				my @res=$self->getList();
				push @result,[@res];
			}
			elsif ($char eq ")") {
				$self->warn("What's a \"$char\" doing here?");
			}
		}
	}
	if ($cur ne "") {
		if (@result) {
			$self->{TREE}=$tree."->".$#result+1;
			$self->storeComment;
			return [@result,$cur];
		}
		else { 
			$self->{TREE}=$tree;
			$self->storeComment;
			return $cur;
		}
	}
	else {
		if (@result>2) {
			$self->{TREE}=$tree."->$#result";
			$self->storeComment;
			return [@result];
		}
		elsif (@result) {
			$self->{TREE}=$tree;
			$self->storeComment;
			return shift @result;
		}
		else {
			return $cur;
		}
	}
}
sub getSingleValue {
	my $self=shift;
	local $_;
	my $res="";
	$res=shift if @_;
	my $char;
	while (defined($char=$self->get())) {
		print "ParsSingle $char\n" if $$self{Debug};
		if ($char!~m/[\=\"\}\{\(\)\s]/) {
			$res.=$char;
		}
		elsif ($char=~m/[\=\"\{\(]/) {
			$self->warn("What's a \"$char\" doing here?");
		}
		elsif ($char=~m/[\}\)]/) {
			$$self{Ret}=$char;
			return $res;
		}
		elsif ($char=~m/\s/) {
			return $res;
		}
	}
	$self->warn ("Unexpected EOF");
	return $res;
}
sub parsList {
	my $self=shift;
	local $_;
	my @result;
	my $cur="";
	my $in=0;
	my $escape=0;	
	my $char;
	my $i=0;
	my $tree=$self->{TREE};
	$self->storeComment;
	#$self->{TREE}=$tree."->0";
	while (defined($char=$self->get())) {
	print "ParsList   $char\n" if $$self{Debug};
		if ($in) {
			if ($char eq "\"") {
				if ($escape) {
					$escape=0;
					$cur.=$char;
				}
				else {
					push @result,$self->deescape($cur);
					$self->storeComment;
					$self->{TREE}=$tree."->".$i++;
					$cur="";
					$in=0;
				}
			}
			elsif ($char eq "\\") {
				if ($escape) {
					$escape=0;
				}
				else {
					$escape=1;
				}
				$cur.=$char;
			}
			else {
				$escape=0;
				$cur.=$char;
			}

		}
		else {
			if ($char!~m/[\=\"\}\{\(\)\s\n]/) {
				$self->storeComment;
				$self->{TREE}=$tree."->".$i++;
				push @result,$self->deescape($self->getSingleValue($char));
			}
			elsif ($char eq "=") {
				$self->warn("What's a \"$char\" doing here?");
			}
			elsif ($char eq "\"") {
				$in=1;
			}
			elsif ($char eq "{") {
				$self->storeComment;
				$self->{TREE}=$tree."->".$i++;
				my %res=$self->parsMap();
				push @result,{%res};
			}
			elsif ($char eq "}") {
				$self->warn("What's a \"$char\" doing here?");
			}
			elsif ($char eq "(") {
				$self->storeComment;
				$self->{TREE}=$tree."->",$i++;
				my @res=$self->parsList();
				push @result,[@res];
			}
			elsif ($char eq ")") {
				$self->storeComment;
				$self->{TREE}=$tree;
				return @result;
			}
		}
	}
	$self->warn ("Unexpected EOF");
	push @result,$cur if ($cur ne "");
	return @result;
}
=head1 NAME

Data::Sofu - Perl extension for Sofu data

=head1 SYNOPSIS

	require Data::Sofu;
	my $sofu=new Sofu;
	%hash=$sofu->read("file.sofu");
	$comments=$sofu->comments;
	$sofu->write("file.sofu",$hashref);
	open FH,">file.sofu";
	$sofu->write(\*FH,$hashref,$comments);
	close FH;
	$texta=$sofu->pack($arrayref);
	$texth=$sofu->pack($hashref);
	$arrayref=$sofu->unpack($texta);
	$arrayhash=$sofu->unpack($texth);

=head1 DESCRIPTION

This Module provides the ability to read and write sofu files of the versions 0.1 and 0.2. Visit L<http://sofu.sf.net> for a description about sofu. 

It can also read not-so-wellformed sofu files and correct their errors. 

Additionally it provides the ability to pack HASHes and ARRAYs to sofu strings and unpack those.

The comments in a sofu file can be preserved if 

=head1 SYNTAX

This class does not export any functions, so you need to call them using object notation.

=head1 FUNCTIONS AND METHODS


=head2 new

Creates a new Data::Sofu object.

=head2 setIndent(INDENT)

Sets the indent to INDENT. Default indent is "\t".

=head2 setWarnings( 1/0 ) 

Enables/Disables sofu syntax warnings.

=head2 comments 

Gets/sets the comments of the last file read

=head2 write(FILE,DATA,[COMMENTS])

Writes a sofu file with the name FILE.
FILE can be:
A reference to a filehandle or
a filename

An existing file of this name will be overwritten.

DATA can be a scalar, a hashref or an arrayref.

The top element of sofu files must be a hash, so any other datatype is converted to {Value=>DATA}.
	
	@a=(1,2,3);
	$sofu->write("Test.sofu",\@a);
	%data=$sofu->read("Test.sofu");
	@a=@{$data->{Value}}; # (1,2,3)

COMMENTS is s reference to hash with comments like the one retuned by comments()

=head2 read(FILE)

Reads the sofu file FILE and returns a hash with the data.
FILE can be:
A reference to a filehandle or
a filename

=head2 pack(DATA)

Packs DATA to a sofu string.
DATA can be a scalar, a hashref or an arrayref.

=head2 unpack(SOFU STRING)

This function unpacks SOFU STRING and returns a scalar, which can be either a string or a reference to a hash or a reference to an array.

=head1 BUGS

Hashes with keys other than strings without whitespaces are not supported due to the restrictions of the sofu file format.

Crossreference will trigger a warning.

Comments written after an object will be rewritten at the top of an object:

	foo = { # Comment1
		Bar = "Baz"
	} # Comment2

will get to:

	foo = { # Comment1
	# Comment 2
		Bar = "Baz"
	} 

=head1 SEE ALSO

perl(1),L<http://sofu.sf.net>

=cut

1;

