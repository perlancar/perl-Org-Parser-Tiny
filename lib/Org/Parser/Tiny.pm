package Org::Parser::Tiny;

use 5.010001;
use strict;
use warnings;

# VERSION

sub new {
    my $class = shift;
    bless {}, $class;
}

sub _parse {
    my ($self, $lines, $opts) = @_;

    my @res;
    my $curlines = [];

    # gather text before the first heading
    while (1) {
        last unless @$lines;
        last if $lines->[0] =~ /^\*+ /;
        push @$curlines, shift(@$lines);
    }
    push @res, {type=>'text', content=>join("",@$curlines)} if @$curlines;

    # gather headlines + their content

    my $is_hl;
    for my $line (@$lines) {
        if ($line =~ /^(\*+) /) {
            $is_hl = 1;
            my $level = length($1);
            push @res, {type=>'headline', headline=>$line, level=>$level,
                        content=>""};
        } else {
            $res[-1]{content} .= $line;
        }
    }

    \@res;
}

sub parse {
    my ($self, $arg, $opts) = @_;
    die "Please specify a defined argument to parse()\n" unless defined($arg);

    $opts //= {};

    my $lines;
    my $r = ref($arg);
    if (!$r) {
        $lines = [split /^/, $arg];
    } elsif ($r eq 'ARRAY') {
        $lines = [@$arg];
    } elsif ($r eq 'GLOB' || blessed($arg) && $arg->isa('IO::Handle')) {
        #$lines = split(/^/, join("", <$arg>));
        $lines = [<$arg>];
    } elsif ($r eq 'CODE') {
        my @chunks;
        while (defined(my $chunk = $arg->())) {
            push @chunks, $chunk;
        }
        $lines = [split /^/, (join "", @chunks)];
    } else {
        die "Invalid argument, please supply a ".
            "string|arrayref|coderef|filehandle\n";
    }
    $self->_parse($lines, $opts);
}

sub parse_file {
    my ($self, $filename, $opts) = @_;
    $opts //= {};

    my $content = do {
        open my($fh), "<", $filename or die "Can't open $filename: $!\n";
        local $/;
        scalar(<$fh>);
    };

    $self->parse($content, $opts);
}

1;
# ABSTRACT: Parse Org documents with as little code (and no non-core deps) as possible

=head1 SYNOPSIS

 use Org::Parser::Tiny;
 my $orgp = Org::Parser::Tiny->new();

 # parse a file
 my $doc = $orgp->parse_file("$ENV{HOME}/todo.org");

 # parse a string
 $doc = $orgp->parse(<<EOF);
 * this is a headline
 * this is another headline
 ** this is yet another headline
 EOF


=head1 DESCRIPTION

This module is a more lightweight alternative to L<Org:Parser>. Currently it is
very simple and can only parse headlines. I use this to write utilities like
L<sort-org-headlines-tiny>.


=head1 ATTRIBUTES


=head1 METHODS

=head2 new()

Create a new parser instance.

=head2 $orgp->parse($str | $arrayref | $coderef | $filehandle, \%opts) => $doc

Parse document (which can be contained in a scalar $str, an array of lines
$arrayref, a subroutine which will be called for chunks until it returns undef,
or a filehandle).

Returns Perl structure representing the document.

Will die if there are syntax errors in documents.

Known options:

=over

=back

=head2 $orgp->parse_file($filename, \%opts) => $doc

Just like parse(), but will load document from file instead.

Known options (aside from those known by parse()):

=over

=back


=head1 FAQ


=head1 SEE ALSO

L<Org::Parser>

=cut
