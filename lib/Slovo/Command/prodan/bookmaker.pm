package Slovo::Command::prodan::bookmaker;
use Mojo::Base 'Slovo::Command', -signatures;
use Mojo::Util qw(encode decode getopt dumper);
use Mojo::JSON qw(from_json);
use Mojo::File qw(path);
use Mojo::Collection qw(c);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

has args =>
  sub { {skus => [], names => '', files => [], email => '', to => 'PDF', send => 0} };
has description => 'Generate password protected PDF from ODT';
has usage       => sub { shift->extract_usage };
has files       => sub { c() };
has tempdir     => sub {
  Mojo::File::tempdir('booksXXXX', TMPDIR => 1, CLEANUP => 0);
};

my %TO_FORMATS = (PDF => \&_files_to_PDF,);
my @vowels     = qw(A Y E I O U);
my @all        = ('A' .. 'Z', 1 .. 9);
my $count      = scalar @vowels;
my $syllables  = c(@all)->shuffle->map(sub { $_ . $vowels[int rand($count)] });

has password => sub {
  $syllables->shuffle->head(5)->join;
};

sub run ($self, @args) {

  # read and validate arguments
  $self->_parse_args(@args);

  # figure out the ODT files to read
  $self->_find_files();

  # copy them for modification with the new filename
  $self->_copy_files;

  # modify the style file footer for each file
  $self->_personalize_files;

  # generate the new PDFs
  $TO_FORMATS{$self->args->{to}}->($self);

  # delete the new ODT files - not needed anymore
  $self->_delete_personalized_files;

  # optionally send an email or just display the url and password
  return $self;
}

sub _parse_args ($self, @args) {
  my $args = $self->args;
  getopt \@args,
    's|skus=s@'  => \($args->{skus}),
    'n|names=s'  => \($args->{names}),
    'e|email=s'  => \($args->{email}),
    'f|files=s@' => \($args->{files}),
    't|to=s'     => \($args->{to}),
    'send'       => \($args->{send});
  $args->{to} = uc $args->{to};
  return $self->args($args);
}

sub _find_files ($self) {
  my $args = $self->args;
  my $skus
    = $self->app->dbx->db->select('products', '*', {sku => {-in => $args->{skus} // []}})
    ->hashes;
  my @files;
  for my $pr (@$skus) {
    my $props = from_json $pr->{properties};
    Carp::croak "$props->{file} does not exist" unless -f $props->{file};
    push @files, $props->{file};
  }

  for my $f (@{$args->{files}}) {
    Carp::croak "$f does not exist" unless -f $f;
    push @files, $f;
  }
  return $self->files(c(@files));
}

sub _copy_files ($self) {
  my $tmp = $self->tempdir;
  eval { $tmp->make_path({mode => 0711}) } or Carp::croak $@;

  # replace the file-names with the new paths
  my $sufix = $syllables->shuffle->head(3)->join;
  $self->files->each(sub {
    my ($f) = $_ =~ m|([^/]+)$|;                # filename only
    $f =~ s/(\.[^.]+)$/-$sufix$1/;              # add the suffix to the basename
    $_ = path($_)->copy_to($tmp->child($f));
  });
  return $self;
}


# add the names and email to the footer
sub _personalize_files ($self) {
  my $args             = $self->args;
  my $styles_file_name = 'styles.xml';
  for my $f (@{$self->files}) {
    my $odt              = Archive::Zip->new($f->to_string);
    my $styles_as_string = $odt->contents($styles_file_name);

    # replace the pattern with personal info - name and email
    $styles_as_string =~ s /NAMES_AND_EMAIL/$args->{names} &lt;$args->{email}&gt;/g;
    $odt->contents($styles_file_name, $styles_as_string);
    $odt->overwrite();
  }

  return $self;
}

sub _files_to_PDF ($self) {

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
    -s, --skus  Unique identifiers of the books in the products table. Can be many.
    -n, --names Names of the person for which to prepare the files.
    -e, --email Email to which to send download links.
    -f, --files Source Filename which to copy, modify and convert. Can be many.
    -t, --to    Format to which to convert the ODT file. For now only PDF.
                Defaults to PDF.
        --send  Boolean. Send the urls to files via email on the provided email.

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

=head2 args

Parsed arguments right after L</run> is invoked.

    $self->args({
      skus  => ['9786199169032'],
      files => 'somewhere/book.odt',
      names => 'Краси Беров',
      to    => 'PDF'
    });
    my $args = $self->args;

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

=cut

