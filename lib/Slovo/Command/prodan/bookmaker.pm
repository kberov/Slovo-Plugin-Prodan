package Slovo::Command::prodan::bookmaker;
use Mojo::Base 'Slovo::Command', -signatures;
use feature qw(lexical_subs);
use Mojo::Util qw(encode decode getopt dumper b64_encode);
use Mojo::JSON qw(from_json);
use Mojo::File qw(path);
use Mojo::Collection qw(c);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use IPC::Cmd qw(can_run);
use Time::Piece ();
use Net::SMTP;

has args => sub { {
  skus    => [],
  names   => '',
  files   => [],
  email   => '',
  to      => 'PDF',
  send    => 0,
  quiet   => 0,
  dom_url => '',
} };
has books_base_url => '/books';
has description    => 'Generate password protected PDF from ODT';
has error          => '';
has usage          => sub { shift->extract_usage };
has files          => sub { c() };
has success        => 0;
has tempdir        => sub {
  Mojo::File::tempdir('booksXXXX', TMPDIR => 1, CLEANUP => 0);
};

my %TO_FORMATS = (PDF => \&_files_to_PDF,);
my @vowels     = qw(A Y E I O U);
my @all        = ('A' .. 'Z', 1 .. 9, qw(_ - $));
my $count      = scalar @vowels;
my $syllables  = c(@all)->shuffle->map(sub { $_ . $vowels[int rand($count)] });

has password => sub {
  my $i = rand $syllables->size - 4;
  join('', @$syllables[$i .. $i + 4]);
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

#say something or return what would be already said
sub _say ($self, $say) {
  push @{$self->{_says} //= []}, $say if $say;
  if (!$self->args->{quiet} && $say) {
    say $say;
    return;
  }
  return $self->{_says} unless $say;
  return;
}


# parse and validate arguments
sub _parse_args ($self, @args) {
  # When running as CGI or service we do not get much parameters and the
  # arguments of this command will be already decoded. When run on the command
  # line, we get all parameters already UTF8 encoded and must decode some of
  # them.
  if(@ARGV>2) { 
    c(@args)->each(sub{$_= decode(utf8=>$_)});
  }
  my $args = $self->args;
  getopt \@args,
    'e|email=s'   => \($args->{email}),
    'd|dom_url=s' => \($args->{dom_url}),
    'f|file=s@'   => \($args->{files}),
    'q|quiet'     => \($args->{quiet}),
    'n|names=s'   => \($args->{names}),
    's|sku=s@'    => \($args->{skus}),
    'send'        => \($args->{send}),
    't|to=s'      => \($args->{to});

  $args->{to} = uc $args->{to};
  # We need at least one file to convert something.
  unless(@{$args->{files}} + @{$args->{skus}}){
    $self->_say($self->usage);
    Mojo::Exception->throw('Either "sku" or "file" must be provided!');
  }

  # Needed for the footer
  unless ($args->{names} && $args->{email}) {
    $self->_say($self->usage);
    Mojo::Exception->throw('Both "email" and "names" must be provided!');
  }
  # If the files' urls will be send via email, we need the domain to construsct
  # the download URLs.
  if($args->{send} && !$args->{dom_url}) {
    $self->_say($self->usage);
    Mojo::Exception->throw('"dom_url" is mandatory if the --send option is set.');
  }

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
    Mojo::Exception->throw("No `file` property found in SKU $pr->{sku}.") unless $props->{file};
    push @files, $self->_find_file($props->{file});
  }

  for my $f (@{$args->{files}}) {
    push @files, $self->_find_file($f);
  }
  return $self->files(c(@files));
}

sub _copy_files ($self) {
  my $tmp = $self->tempdir;
  eval { $tmp->make_path({mode => oct(711)}) } or Mojo::Exception->throw($@);

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
    $self->_say("Personalized $f.")
  }

  return $self;
}

# man unoconv
# https://wiki.openoffice.org/wiki/API/Tutorials/PDF_export
sub _files_to_PDF ($self) {
  state $app       = $self->app;
  state $pdf_dir   = $app->home->child('/data/pdf');
  state $full_path = can_run('unoconv');
  Mojo::Exception->throw(
    'unoconv was not found! Please install it first. ',
    'On Debian and derivatives `sudo apt install unoconv`'
  ) unless $full_path;
  my $output_dir
    = eval { path("$pdf_dir/_" . Time::Piece->new->ymd)->make_path({mode => oct(711)}); }
    or Mojo::Exception->throw($@);

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
        $self->_say(qq|Produced file $f with password "${\ $self->password }".|)
      }
      else {
        my $error = "$f was not produced. Try to debug what unoconv did.";
        $app->log->error($error);
        $self->error($self->error . $/ . $error);
        Mojo::Exception->throw($error);
      }
    });
    $self->tempdir->remove_tree;
  }
  return $self;
}

my sub _subject {
  return
      'Поръчка на книг'
    . ($_[0]->files->size > 1 ? 'и' : 'а')
    . '. ISBN: '
    . (join ',', @{$_[0]->args->{skus} // []});
}

my sub _body ($self) {
  state $one  = {ebook => 'електронна книга', _link => 'връзка', it => 'ѝ',};
  state $many = {ebook => 'електронни книги', _link => 'връзки', it => 'им',};
  my $words = $self->files->size > 1 ? $many : $one;
  my $links = $self->files->map(sub {
    my ($f) = $_ =~ m|(/[\w-]+/[^/]+)$|;
    my $url= $self->args->{dom_url} . $self->books_base_url . $f;
    $self->_say("Prepared download URL: $url");
    return $url;
  });
  return <<"BODY";
Здравейте, ${\ $self->args->{names} }.
Получавате това писмо, защото поръчахте $words->{ebook} в слово.бг.
Ето $words->{_link} за изтеглянето $words->{it}.

${\ $links->join($/) }

С балгодарност,
Студио Беров
BODY

}

sub _send_file_urls ($self) {
  state $app = $self->app;
  my $config = c(@{$app->config->{load_plugins}})
    ->first(sub { ref $_ eq 'HASH' && exists $_->{Prodan} });
  $config = $config->{Prodan}{'Net::SMTP'};
  my $args = $self->args;
  my $body = <<"BODY";
Проба алабаланица с турска паница
BODY
  my $message = <<"MAIL";
To: $args->{email}
From: $config->{mail}
Subject: =?UTF-8?B?${\ b64_encode(encode('UTF-8', _subject($self)), '') }?=
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: 8bit
Message-Id: <acc-msg-to-$args->{email}${\ time}>
Date: ${\ Mojo::Date->new->to_datetime }
MIME-Version: 1.0

${\ encode('UTF-8' => _body($self))}

MAIL

  my $smtp = Net::SMTP->new(%{$config->{new}}) or do {
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
    $self->_say("Message with download urls sent to $args->{email}.");
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
    slovo prodan bookmaker --sku 9786199169032 --sku 9786199169018 dom_url https://example.com -send

  Options:
    -e, --email   Email to which to send download links. Mandatory
    -d, --dom_url URL of the domain from which the download links will be
                  downloaded. Mandatory if the --send option is set.
    -f, --file    Source Filename which to copy, modify and convert. Can be many.
    -q, --quiet   Do not print to STDOUT what is being done.
    -n, --names   Names of the person for which to prepare the files. Mandatory
    -s, --sku     Unique identifiers of the books in the products table. Can be many.
        --send    Should an email with download links be send to the provided email?
    -t, --to      Format to which to convert the ODT file. For now only PDF.
                  Defaults to PDF.
        --send    Boolean. Send the urls to files via email to the provided email address.


=head1 DESCRIPTION

Slovo::Command::prodan::bookmaker is a command that converts a list of ODT
files, found in the properties of the products table or passed on the command
line to PDF by using LibreOffice in headless mode. Given the arguments
C<--names> and C<--email>, it adds this information to the footer of each page
in the prepared books. A password is set for the created books. To the name of
the newly created PDFs the first part of the email is appended. The file-names
of the newly created PDFs and the password are printed on the command-line.
Additionally they are availble in the attributes L</files> and L</password> of
the command object. This is for cases when the command is not run on the
command line.

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

=head2 books_base_url

Base url of the books to be downloaded. It will be prepended to theparent
forlder of the files. It is expected tha the inovker of this command (command
line or a controller) provides a base url with a domain name.

    $cmd = $cmd->books_base_url('https://слово.бг');
    my $url = $cmd->books_base_url;

=head2 description

Description of the command - string.

    my $descr = $bookmaker->description;

=head2 error

A string containg newline separated error mesages, collected during run.


=head2 files

Mojo::Collection of paths to the prepared files.

    my $files = $bookmaker->files;
    my $files = $bookmaker->run(@args)->files;

=head2 password

Password for opening the prepared PDFs.

    $bookmaker->password;

=head2 success

    Bolean, indicating if the command finished successfuly or not.

=head2 tempdir

Atemporary directory under C</tmp>

=head2 usage

The extracted SYNOPSIS - string.

    my $usage = $bookmaker->usage


=head1 METHODS

Slovo::Command::prodan::bookmaker implements the following methods.


=head2 run

Implementation of the execution of the command. Returns C<$self>.

    $bookmaker = $bookmaker->run(@args);

=cut

