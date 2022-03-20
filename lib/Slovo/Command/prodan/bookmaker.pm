package Slovo::Command::prodan::bookmaker;
use Mojo::Base 'Slovo::Command', -signatures;
use Mojo::Util qw(encode decode getopt dumper);
use Mojo::Collection qw(c);

has description => 'Generate password protected PDF from ODT';
has usage   => sub { shift->extract_usage };
has files => sub {c()};

my @vowels = qw(A Y E I O U);
my @all = ('A' .. 'Z','!','@',';','.','~','%','#','^','*','-','_','+','=','/','?');
my $count = scalar @vowels;
my $syllables =    c(@all)->shuffle->map(sub{ $_.$vowels[int rand($count)]});

has password => sub {
    $syllables->shuffle->head(5)->join;   
};

sub run ($self, @args) {

    return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Command::prodan::bookmaker - generate password protected PDF from ODT.

=head1 SYNOPSIS

  Usage:
    slovo prodan bookmaker --sku 9786199169032 --sku 9786199169018
    slovo prodan bookmaker --sku 9786199169025 --quiet 
    slovo prodan bookmaker --sku 9786199169025 --names 'Краси Беров' --email berov@cpan.org
    slovo prodan bookmaker --sku 9786199169025 --names 'Краси Беров' --email berov@cpan.org --to PDF
    slovo prodan bookmaker --file book1.odt --file book2.odt --to PDF

  Options:
    -h, --help  Show this summary of available options
    -s, --sku   Unique identifier of the book in the products table. Can be many.
    -n, --names Names of the person for which to prepare the files.
    -e, --email Email to which to send download links.
    -f, --file  Filename which to convert. Can be many.
    -t, --to    Format to which to convert the ODT file. For now only PDF.

=head1 DESCRIPTION

Slovo::Command::prodan::bookmaker is a command that converts a list of ODT
files, found in the properties of the products table to PDF by using
LibreOffice in headless mode. Given the arguments C<--names> and C<--email>, it
adds this information to the footer of each page in the prepared books. A
password is set for the created books. To the name of the newly created PDFs
the first part of the email is appended. The file-names of the newly created PDFs and
the password are printed on the command-line. Additionally they are availble in
the attributes L</files> and L</password> of the command object. This is for
cases when the command is not run on the command line.

Finaly the command may send an email message to the given email that the books
are ready. The message will contain links to the prepared PDF files to be
downloaded by the owner of the email.

The command also can create such password protected PDF from any given ODT
file.

=head1 ATTRIBUTES

Slovo::Command::prodan::bookmaker has the following attributes.

=head2 description

Description of the command - string.

    my $descr = $bookmaker->description;

=head2 files

Mojo::Collection of paths to the prepared files.

    my $files = $bookmaker->files;
    my $files = $bookmaker->run(@args)->files;

=head2 password

Password for opening the prepared PDFs.

    $bookmaker->password;

=head2 usage

The extracted SYNOPSIS - string.

    my $usage = $bookmaker->usage


=head1 METHODS

Slovo::Command::prodan::bookmaker implements the following methods.


=head2 run

Implementation of the execution of the command. Returns C<$self>.

    $bookmaker = $bookmaker->run(@args);
