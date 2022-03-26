# t/006_bookmaker.t
use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::File qw(path tempdir);
use YAML::XS;
use IPC::Cmd;
my $BKMKR = 'Slovo::Command::prodan::bookmaker';

unless (IPC::Cmd::can_run('unoconv')) {
  plan(skip_all => "'unoconv' is needed for $BKMKR to work. "
      . 'Please install it. Debian and derivatives: sudo apt install unoconv');
}

BEGIN {
  $ENV{MOJO_CONFIG} = path(__FILE__)->dirname->to_abs->child('slovo.conf');
};
note $ENV{MOJO_CONFIG};
my $install_root = tempdir('slovoXXXX', TMPDIR => 1, CLEANUP => 0);
my $t            = Test::Mojo->with_roles('+Slovo')->install(

# from => to
  undef() => $install_root,

# 0777
)->new('Slovo');
my $app  = $t->app;
my $home = $app->home;

# add some products which have files
my $prepare_products = sub {
  my $PRD = 'Slovo::Command::prodan::products';
  require_ok($PRD);
  my $command = $PRD->new(app => $app)->run('create', '-f' => 't/products.yaml');
  isa_ok($command => $PRD);
};
require_ok($BKMKR);
my $parse_args = sub {

  my $cmd = $BKMKR->new(app => $app);
  isa_ok($cmd => $BKMKR);
  $cmd->_parse_args(());

#note explain $cmd->args;
  my $default_args = {
    'email' => '',
    'files' => [],
    'names' => '',
    'send'  => 0,
    'skus'  => [],
    'to'    => 'PDF'
  };
  is_deeply($cmd->args => $default_args, 'Default arguments');

  $cmd->_parse_args(
    '--files' => 'book.odt',
    '--skus'  => '9786199169032',
    '--files' => 'another.odt'
  );
  is_deeply($cmd->args->{files}, ['book.odt', 'another.odt'], 'files are an ARRAYREF');
  is_deeply($cmd->args->{skus},  ['9786199169032'],           'skus are an ARRAYREF');
};

my $find_skus_and_files = sub {
  my $cmd = $BKMKR->new(app => $app);
  eval { $cmd->args({files => ['t/nobook.odt']})->_find_files };
  like($@ => qr/does not exist/, 'Error:' . $@);
  $cmd->args({files => ['t/book.odt'], skus => ['9786199169032']})->_find_files;
  is(scalar @{$cmd->files} => 2, 'we have two files');
  note explain $cmd->files;

};

my $copy_files = sub {

  my $cmd = $BKMKR->new(app => $app);
  $cmd->args({files => ['t/book.odt'], skus => ['9786199169032']})
    ->_find_files->_copy_files;
  $cmd->files->each(sub {
    like $_=> qr|books\w+/.+?-[A-Z1-9]{4}.odt|, 'File copied with random suffix';
    ok(-f $_, 'file exists');
  });

};

my $personalize_files = sub {

  my $cmd = $BKMKR->new(app => $app);
  $cmd->args({
    files => ['t/book.odt'],
    skus  => ['9786199169032'],
    names => Mojo::Util::encode(utf8 => 'Краси Беров'),
    email => 'berov@cpan.org'
  })->_find_files->_copy_files->_personalize_files;
  my $odt = Archive::Zip->new($cmd->files->[0]->to_string);

  my $styles_as_string = $odt->contents('styles.xml');
  ok(($styles_as_string !~ /NAMES_AND_EMAIL/), 'Pattern was replaced with personal data');
};

my $convert_files = sub {

  my $cmd = $BKMKR->new(app => $app);
  $cmd->args({
    files => ['t/book.odt'],
    skus  => ['9786199169032'],
    names => Mojo::Util::encode(utf8 => 'Краси Беров'),
    email => 'berov@cpan.org',
    to    => 'PDF'
  })->_find_files;
  my $found_files = $cmd->files->size;
  $cmd->_copy_files->_personalize_files->_files_to_PDF();

  ok $cmd->success => 'convert suceeded';
  note explain $cmd->files;
  is $cmd->files->size => $found_files, "$found_files file(s) produced";
  $cmd->files->each(sub { like $_ => qr/\.pdf$/i, "file is a PDF file" });
  ok(!-d $cmd->tempdir, $cmd->tempdir . ' was removed with files in it.');
  note 'Password: ' . $cmd->password;
};

my $send_files_urls = sub {
SKIP: {
    skip
      'Please set SLOVO_PRODAN_MAIL_HOST,SLOVO_PRODAN_MAIL_FROM and SLOVO_PRODAN_MAIL_PASSW!'
      unless ($ENV{SLOVO_PRODAN_MAIL_HOST}
      && $ENV{SLOVO_PRODAN_MAIL_FROM}
      && $ENV{SLOVO_PRODAN_MAIL_PASSW});

    my $cmd = $BKMKR->new(app => $app);
    $cmd->run(
      '-f' => 't/book.odt',
      '-s' => '9786199169032',
      '-n' => 'Краси Беров',
      '-e' => 'berov@cpan.org',
      '--send'
    );
    ok(1, 'ok');
  }
};

subtest 'Prepare products' => $prepare_products;

#subtest 'Parse arguments'     => $parse_args;
#subtest 'Find SKUs and Files' => $find_skus_and_files;
#subtest 'Copy files'          => $copy_files;
subtest 'Personalize files' => $personalize_files;
subtest 'Convert files'     => $convert_files;
subtest 'Send files\' urls' => $send_files_urls;

done_testing;
