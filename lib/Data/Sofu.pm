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
$VERSION="0.21";

sub new {
	my $self={};
	shift;
	$$self{CurFile}="";
	$$self{Counter}=0;
	$$self{WARN}=1;
	$$self{Debug}=0;
	$$self{Ref}=[];
	$$self{Indent}="";
	$$self{SetIndent}="";
	$$self{String}=[];
	$$self{READLINE}=[];
	$$self{Libsofucompat}=0;
	bless $self;
	return $self;
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
sub writeList {
	my $self=shift;
	local $_;
	my $deep=shift;
	my $ref=shift;
	my $res="";
	foreach (@{$$self{Ref}}) {
		$res.="\"\"" and $self->warn("Cross-reference ignored") and return 0 if $_ == $ref;
	}
	push @{$$self{Ref}},$ref;
	$res.="(\n";
	foreach my $r (@{$ref}) {
		if (not ref($r)) {
			$res.=$$self{Indent} x $deep."\"".$self->escape($r)."\"\n";
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
		
	}
	return $res.$$self{Indent} x --$deep.")\n";
}
sub writeMap {
	my $self=shift;
	local $_;
	my $deep=shift;
	my $ref=shift;
	my $res="";
	foreach (@{$$self{Ref}}) {
		$res.="\"\"" and $self->warn("Cross-reference ignored") and return $res if $_ == $ref;
	}
	push @{$$self{Ref}},$ref;
	$res.="{\n" if $deep or not $$self{Libsofucompat};
	foreach (sort keys %{$ref}) {
		unless (ref $$ref{$_}) {
			$res.=$$self{Indent} x $deep."$_ = \"".$self->escape($$ref{$_})."\"\n";
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
	$$self{CurFile}=shift;
	my $ref=shift;
	local $_;
	open FH,">",$$self{CurFile} or die "Sofu error open: $$self{CurFile} file: $!";
	$$self{Indent}="\t" unless $$self{SetIndent};
	$$self{Libsofucompat}=1;
	unless (ref $ref) {
		print FH "Value=".$self->escape($ref);
	}
	elsif (ref $ref eq "HASH") {
		print FH $self->writeMap(0,$ref);
	}
	elsif (ref $ref eq "ARRAY") {
		print FH "Value=".$self->writeList(0,$ref);
	}
	else {
		$self->warn("non Sofu reference");
		return "";
	}
	$$self{Libsofucompat}=0;
	$$self{Indent}="";
	close FH;
	$$self{CurFile}="";
	return 1;
}


sub read {
	my $self=shift;
	local $_;
	$$self{CurFile}=shift;
	open FH,$$self{CurFile} or die "Sofu error open: $$self{CurFile} file: $!";
	my $text=do {local $/,<FH>};
	close FH;
	return %{$self->unpack($text)};
	$$self{CurFile}="";
}
sub pack {
	my $self=shift;
	local $_;
	my $ref=shift;
	local $_;
	@{$$self{Ref}}=();
	$$self{Indent}=$$self{SetIndent} if $$self{SetIndent};
	$$self{Counter}=0;
	unless (ref $ref) {
		return $self->escape($ref);
	}
	elsif (ref $ref eq "HASH") {
		return $self->writeMap(0,$ref);
	}
	elsif (ref $ref eq "ARRAY") {
		return $self->writeList(0,$ref);
	}
	else {
		$self->warn("non Sofu reference");
		return "";
	}
}
sub unpack($) {
	my $self=shift;
	local $_;
	$$self{Counter}=0;
	$$self{Line}=1;
	$$self{String}=[grep {$_} split /\n/,shift];
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
		my @temp=split //,$$self{Ret};
		my $ch=shift @temp;
		$$self{Ret}=join ("",@temp);
		return $ch;
	}
	return shift if @_ and $_[0] and $_[0]!="";
	my $c=undef;
	unless (@{$$self{READLINE}}) {
		chomp($a=shift @{$$self{String}});
		if ($a) {
			my @temp=split //,$a;
			my $string=0;
			my $escape=0;
			my $char;
			while (defined($char=shift @temp)) {
				if ($char eq "\"") {
					$string=!$string unless $escape;
				}
				if ($char eq "\\") {
					$escape=!$escape;
				}
				else {
					$escape=0;
				}
				if ($char eq "#" and not $string and not $escape) {
					last;
				}
					
				push @{$$self{READLINE}},$char;
			}
			push @{$$self{READLINE}},"\n";
		}
	}
	
	$c=shift @{$$self{READLINE}} if @{$$self{READLINE}};
	++$$self{Counter};
	if ($c eq "\n") {
		$$self{Counter}=0;
		$$self{Line}++;
	}
	
	print "END" if not defined $c and $$self{Debug} ;
	return $c;
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
	while (defined($char=$self->get())) {
		print "ParsCompos  $char\n" if $$self{Debug};
		if ($char!~m/[\=\"\}\{\(\)\s\n]/s) {
			if ($eq) {
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
			$eq=1;
		}
		elsif ($char eq "{") {
			$self->warn("Missing \"=\"!") unless $eq;
			$self->warn("MapEntry unnamed!") if ($comp eq "");
			my %res=$self->parsMap();
			$result{$comp} = {%res};
			$comp="";
			$eq=0;
		}
		elsif ($char eq "}") {
			return %result;
		}
		elsif ($char eq "\"") {
			if (not $eq) {
				return $self->parsValue();
			}
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
					return [@result]
				}
				elsif (@result) {
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
				my %res=$self->parsMap();
				push @result,{%res};
			}
			elsif ($char=~m/[\}\)]/) {
				$$self{Ret}=$char;
				if ($cur ne "") {
					if (@result) {
						return [@result,$cur]
					}
					else { 
						return $cur;
					}
				}
				else {
					if (@result>2) {
						return [@result]
					}
					elsif (@result) {
						return shift @result;
					}
					else {
						return undef;
					}
				}
			}
			elsif ($char eq "(") {
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
			return [@result,$cur]
		}
		else { 
			return $cur;
		}
	}
	else {
		if (@result>2) {
			return [@result]
		}
		elsif (@result) {
			return shift @result;
		}
		else {
			return undef;
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
				push @result,$self->deescape($self->getSingleValue($char));
			}
			elsif ($char eq "=") {
				$self->warn("What's a \"$char\" doing here?");
			}
			elsif ($char eq "\"") {
				$in=1;
			}
			elsif ($char eq "{") {
				my %res=$self->parsMap();
				push @result,{%res};
			}
			elsif ($char eq "}") {
				$self->warn("What's a \"$char\" doing here?");
			}
			elsif ($char eq "(") {
				my @res=$self->parsList();
				push @result,[@res];
			}
			elsif ($char eq ")") {
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
	$sofu->write("file.sofu",\%hash);
	$sofu->write("file.sofu",$hashref);
	$texta=$sofu->pack($arrayref);
	$texth=$sofu->pack($hashref);
	$arrayref=$sofu->unpack($texta);
	$arrayhash=$sofu->unpack($texth);

=head1 DESCRIPTION

This Module provides the ability to read and write sofu files of the versions 0.1 and 0.2. Visit L<http://sofu.sf.net> for a description about sofu. 

It can also read not-so-wellformed sofu files and correct their errors. 

Additionally it provides the ability to pack HASHes and ARRAYs to sofu strings and unpack those.

=head1 SYNTAX

This class does not export any functions, so you need to call them using object notation.

=head1 FUNCTIONS AND METHODS


=head2 new

Creates a new Data::Sofu object.

=head2 setIndent(INDENT)

Sets the indent to INDENT. Default indent is "\t".

=head2 setWarnings( 1/0 ) 

Enables/Disables sofu syntax warnings.

=head2 write(FILE,DATA)

Writes a sofu file with the name FILE.

An existing file of this name will be overwritten.

DATA can be a scalar, a hashref or an arrayref.

The top element of sofu files must be a hash, so any other datatype is converted to {Value=>DATA}.
	
	@a=(1,2,3);
	$sofu->write("Test.sofu",\@a);
	%data=$sofu->read("Test.sofu");
	@a=@{$data->{Value}}; # (1,2,3)

=head2 read(FILE)

Reads the sofu file FILE and returns a hash with the data.

=head2 pack(DATA)

Packs DATA to a sofu string.
DATA can be a scalar, a hashref or an arrayref.

=head2 unpack(SOFU STRING)

This function unpacks SOFU STRING and returns a scalar, which can be either a string or a reference to a hash or a reference to an array.

=head1 BUGS

Hashes with keys other than strings without whitespaces are not supported due to the restrictions of the sofu file format.

Crossreference will trigger a warning.

=head1 SEE ALSO

perl(1),L<http://sofu.sf.net>

=cut

1;
