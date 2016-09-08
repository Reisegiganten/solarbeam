use inc::Module::Install;

name     'SolarBeam';
author   q{Nicolas Mendoza <nicolas@reisegiganten.no>};
license  'perl';
version  '1.20160901';

configure_requires 'Module::Install';

build_requires 'Test::More';

requires 'Data::Dumper';
requires 'Data::Page';
requires 'Mojolicious';
requires 'Mojo::JSON::MaybeXS';

test_requires 'Test::More';

auto_install;

WriteAll;
