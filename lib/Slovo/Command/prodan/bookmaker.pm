package Slovo::Command::prodan::bookmaker;
use Mojo::Base 'Slovo::Command', -signatures;
use Mojo::Util qw(encode decode getopt dumper b64_encode);
use Mojo::JSON qw(from_json);
use Mojo::File qw(path);
use Mojo::Collection qw(c);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use IPC::Cmd qw(can_run);
use Time::Piece ();
use Net::SMTP;
has args =>
  sub { {skus => [], names => '', files => [], email => '', to => 'PDF', send => 0} };
has description => 'Generate password protected PDF from ODT';
has error       => '';
has usage       => sub { shift->extract_usage };
has files       => sub { c() };
has success     => 0;
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


  # optionally send an email or let the caller take care.
  $self->_send_file_urls if $self->success && $self->args->{send};
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
  @{$args->{files}} + @{$args->{skus}}
    || Mojo::Exception->throw('Either "skus" or "files" must be provided!');
  ($args->{names} && $args->{email})
    || Mojo::Exception->throw('Both "email" and "names" must be provided!');
  return $self->args($args);
}

# Try to find the file in the current directory or under $app->home if the path
# is not absolute.
sub _find_file ($self, $file_str) {
  if (index($file_str, '/', 0) != 0) {
    if (-f (my $f = $self->app->home->child($file_str)))  { return $f; }
    if (-f (my $f = path(Cwd::getcwd)->child($file_str))) { return $f; }
  }
  elsif (-f $file_str) {
    return path($file_str);
  }
  Carp::croak("$file_str does not exist!");
}

sub _find_files ($self) {
  my $args = $self->args;
  my $skus
    = $self->app->dbx->db->select('products', '*', {sku => {-in => $args->{skus} // []}})
    ->hashes;
  my @files;
  for my $pr (@$skus) {
    my $props = from_json $pr->{properties};
    Carp::croak("No `file` property found in SKU $pr->{sku}.") unless $props->{file};
    push @files, $self->_find_file($props->{file});
  }

  for my $f (@{$args->{files}}) {
    push @files, $self->_find_file($f);
  }
  return $self->files(c(@files));
}

sub _copy_files ($self) {
  my $tmp = $self->tempdir;
  eval { $tmp->make_path({mode => 0711}) } or Carp::croak $@;

  # replace the file-names with the new temporary paths
  my $sufix = $syllables->shuffle->head(2)->join;
  $self->files->each(sub {
    my ($f) = $_ =~ m|([^/]+)$|;                 # filename only
    $f =~ s/(\.[^\.]+)$/-$sufix$1/;              # add the suffix to the basename
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
    $odt->contents($styles_file_name, encode utf8 => $styles_as_string);
    $odt->overwrite();
  }

  return $self;
}

# man unoconv
# https://wiki.openoffice.org/wiki/API/Tutorials/PDF_export
sub _files_to_PDF ($self) {
  state $app       = $self->app;
  state $pdf_dir   = $app->home->child('/data/pdf');
  state $full_path = can_run('unoconv');
  Carp::croak(
    'unoconv was not found! Please install it first. ',
    'On Debian and derivatives `sudo apt install unoconv`'
  ) unless $full_path;
  my $output_dir
    = eval { path("$pdf_dir/_" . Time::Piece->new->ymd)->make_path({mode => 0711}); }
    or Carp::croak $@;

  my $files   = $self->files->map(sub { $_->to_string });
  my $unoconv = [
    $full_path,
    '-e' => 'ReduceImageResolution=true',
    '-e' => 'MaxImageResolution=96',
    '-e' => 'ExportBookmarks=true',
    '-e' => 'InitialView=1',
    '-e' => 'Magnification=2',
    '-e' => 'OpenBookmarkLevels=3',
    '-e' => 'EncryptFile=true',
    '-e' => 'DocumentOpenPassword=' . $self->password,
    '-e' => 'RestrictPermissions=true',
    '-e' => 'Printing=0',
    '-e' => 'Changes=0',
    '-e' => 'EnableCopyingOfContent=false',
    '-e' => 'EnableTextAccessForAccessibilityTools=false',
    '-f' => 'pdf',
    '-o' => $files->size > 1
    ? $output_dir
    : $output_dir->child($files->first =~ m|([^/]+)$|),
    @$files
  ];
  my ($success, $error_message, $full_buf, $stdout_buf, $stderr_buf)
    = IPC::Cmd::run(command => $unoconv, verbose => 0);

  if (!$success) {
    my $error = qq|Error generating PDFs from files ${\$files->join(',')}:$/|
      . join($/,
      $error_message,
      join($/, @$full_buf),
      join($/, @$stdout_buf),
      join($/, @$stderr_buf));
    $self->error($error);
    $app->log->error($error);
  }
  else {
    $self->success(1);
    $self->files->each(sub {
      my ($f) = $_ =~ m|([^/]+)$|;    # filename only
      $f =~ s/odt$/pdf/;
      $f = path($output_dir)->child($f);
      if (-f $f) {
        $_ = $f;
      }
      else {
        my $error = "$f was not produced. Try to debug what unoconv did.";
        $app->log->error($error);
        $self->error($self->error . $/ . $error);
        Carp::croak($error);
      }
    });
    $self->tempdir->remove_tree;
  }
  return $self;
}


sub _send_file_urls ($self) {
  state $app    = $self->app;
  my $config = c(@{$app->config->{load_plugins}})
    ->first(sub { ref $_ eq 'HASH' && exists $_->{Prodan} });
  $config = $config->{Prodan}{'Net::SMTP'};
  warn dumper($config);
  my $subject = 'Поръчка на книга';
  my $args    = $self->args;
  my $body    = <<"BODY";
Проба алабаланица с турска паница
BODY
  my $message = <<"MAIL";
To: $args->{email}
From: $config->{mail}
Subject: =?UTF-8?B?${\ b64_encode(encode('UTF-8', $subject), '') }?=
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: 8bit
Message-Id: <acc-msg-to-$args->{email}${\ time}>
Date: ${\ Mojo::Date->new->to_datetime }
MIME-Version: 1.0

${\ encode('UTF-8', $body)}

MAIL

  my $smtp;
  $smtp = Net::SMTP->new(%{$config->{new}}) or do {
    my $error = "Net::SMTP could not instantiate: $@";
    $app->log->error($error);
    Mojo::Exception->throw($error);
  };
  $smtp->auth(@{$config->{auth}});
  $smtp->mail($config->{mail});

  if ($smtp->to($args->{email})) {
    $smtp->data;
    $smtp->datasend($message);
    $smtp->dataend();
  }
  else {
    $app->log->error('Net::SMTP Error: ' . $smtp->message());
    $app->log->error('This affects the sending of book(s) to: ' . $args->{names});
  }

  $smtp->quit;
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

Slovo::Command::prodan::bookmaker has the following attributes. They are
populated during L</run> and available after L</run> returns.

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

