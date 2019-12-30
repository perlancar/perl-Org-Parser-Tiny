use 5.010001;
use strict;
use warnings;

package Org::Parser::Tiny;

# AUTHORITY
# DATE
# DIST
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
    push @res, Org::Parser::Tiny::Node::Head->new(
        {type=>'text', content=>join("",@$curlines)} if @$curlines;

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

    $opts ||= {};

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
    $opts ||= {};

    my $content = do {
        open my($fh), "<", $filename or die "Can't open $filename: $!\n";
        local $/;
        scalar(<$fh>);
    };

    $self->parse($content, $opts);
}


# abstract class: Org::Parser::Tiny::Node
package Org::Parser::Tiny::Node;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
}

sub parent { $_[0]{parent} }
sub children { $_[0]{children} || [] }
sub as_string { $_[0]{raw} }


# abstract class: Org::Parser::Tiny::HasPreamble
package Org::Parser::Tiny::Node::HasPreamble;

our @ISA = qw(Org::Parser::Tiny::Node);

sub new {
    my ($class, %args) = @_;
    $args{preamble} //= "";
    $class->SUPER::new(%args);
}

sub as_string {
    $_[0]->{preamble} . join("", map { $_->as_string } @{ $_[0]->children });
}


# class: Org::Parser::Tiny::Document: top level node
package Org::Parser::Tiny::Node::Document;

our @ISA = qw(Org::Parser::Tiny::Node::HasPreamble);


# class: Org::Parser::Tiny::Node::Headline: headline with its content
package Org::Parser::Tiny::Node::Headline;

our @ISA = qw(Org::Parser::Tiny::Node::HasPreamble);

sub level { $_[0]{level} }

sub tree { $_[0]{tree} }

sub is_todo { $_[0]{is_todo} }

sub is_done { $_[0]{is_done} }

sub todo_state { $_[0]{todo_state} }

sub tags { $_[0]{tags} || [] }

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

Dump document structure using L<Tree::Dump>:

 use Tree::Dump;
 td($doc);

Select document nodes using L<Data::CSel>:

 use Data::CSel qw(csel);

 # select headlines with "foo" in their title
 my @nodes = csel(
     {class_prefixes => ["Org::Parser::Tiny::Node"]},
     "Headline[title =~ /foo/]"
 );

Manipulate tree nodes with path-like semantic using L<Tree::FSLike>:

 use Tree::FSLike;
 my $fs = Tree::FSLike->new(
     tree => $doc,
     gen_filename_method => sub { $_[0]->can("title") ? $_[0]->title : "$_[0]" },
 );

 # list nodes right above the root node
 my @nodes = $fs->ls;

 # use wildcard to list nodes
 my @nodes = $fs->ls("*foo*");

 # remove top-level headlines which have "foo" in their title
 $fs->rm($doc, "/*foo*");


=head1 DESCRIPTION

This module is a more lightweight alternative to L<Org:Parser>. Currently it is
very simple and only parses headlines. I use this to write utilities like
L<sort-org-headlines-tiny>.


=head1 ATTRIBUTES


=head1 METHODS

=head2 new

Usage:

 my $orgp = Org::Parser::Tiny->new;

Constructor. Create a new parser instance.

=head2 parse

Usage:

 my $doc = $orgp->parse($str | $arrayref | $coderef | $filehandle, \%opts);

Parse document (which can be contained in a $str, an array of lines $arrayref, a
$coderef which will be called for chunks until it returns undef, or a
$filehandle.

Returns a tree of node objects (of class C<Org::Parser::Tiny::Node> and its
subclasses C<Org::Parser::Tiny::Node::Document> and
C<Org::Parser::Tiny::Node::Headline>). The tree node complies to
L<Role::TinyCommons::Tree::Node> role, so these tools are available:
L<Data::CSel>, L<Tree::Dump>, L<Tree::FSLike>, etc.

Will die if there are syntax errors in documents.

Known options:

=over

=back

=head2 parse_file

Usage:

 my $doc = $orgp->parse_file($filename, \%opts);

Just like L</parse>, but will load document from file instead.

Known options (aside from those known by parse()):

=over

=back


=head1 FAQ


=head1 SEE ALSO

L<Org::Parser>, the more fully featured Org parser.

L<https://orgmode.org>

=cut
