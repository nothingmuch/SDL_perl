#! perl -w
#
# Copyright (C) 2003 chromatic 
# Copyright (C) 2004 David J. Goehrig
# Copyright (C) 2009 Kartik Thakore

use strict;
use warnings;
use Carp;
use lib  'make/lib';

use Data::Dumper;
use SDL::Build;
use SDL::Utility;
use YAML;
use YAML::Node;

print STDERR <<BROKENWIN if ($^O =~ /MSWin.*|cygwin/ );
******************************** !!!WARNING!!! ******************************** 
Windows support is currently experimental - you can continue, but you've been warned! 
If you are interested in helping please contact us at sdl-devel\@perl.org.
*******************************************************************************
BROKENWIN

my $sdl_compile_flags = SDL::Utility->sdl_c_flags();
my $sdl_link_flags    = SDL::Utility->sdl_libs();
# subsystem to build
#	file
#		location of source file => location of build file to get name right
#	libraries
#		name of shared library (soname)
#			preprocessor definition
#			name of header file
my %subsystems =
(
	SDL => {
		file      => {
			from  => 'src/SDL.xs',
			to    => 'lib/SDL_perl.xs',
		},
		libraries => [qw( SDL SDL_image SDL_mixer SDL_net SDL_ttf SDL_gfx
		                  png jpeg smpeg )],
	},
	Rect => {
		file      => {
			from  => 'src/Rect.xs',
			to    => 'lib/SDL/Rect.xs',
		},
		libraries => [qw( SDL  )],
	},
	
	OpenGL => {
		file      => {
			from => 'src/OpenGL.xs',
			to   => 'lib/SDL/OpenGL.xs', 
		},
		libraries => [qw( SDL GL GLU )],
	},
	SFont => {
		file	=> {
			from => 'src/SFont.xs',
			to   =>	'lib/SDL/SFont.xs',
		},
		libraries => [qw( SDL SDL_image )],
	},	
);

my %libraries = (
	SDL         => {
		define => 'HAVE_SDL', 
		header => 'SDL.h',
	},
	SDL_image   => {
		define => 'HAVE_SDL_IMAGE',   
		header => 'SDL_image.h'
	},
	SDL_mixer   => {
		define => 'HAVE_SDL_MIXER',   
		header => 'SDL_mixer.h'
	},
	SDL_net     => {
		define => 'HAVE_SDL_NET',     
		header => 'SDL_net.h'
	},
	SDL_ttf     => {
		define => 'HAVE_SDL_TTF',     
		header => 'SDL_ttf.h'
	},
	SDL_gfx     => {
		define => 'HAVE_SDL_GFX',     
		header => 'SDL_gfxPrimitives.h'
	},
	png         => {
		define    => 'HAVE_PNG',
		header    => 'png.h',
	},
	jpeg        => {	
		define    => 'HAVE_JPEG',
		header    => 'jpeglib.h',
	},
	smpeg       => {
		define    => 'HAVE_SMPEG',
		header    => 'smpeg.h',
	},
	GL          => {
		define => 'HAVE_GL',  
		header => 'gl.h'
	},
	GLU         => {
		define => 'HAVE_GLU', 
		header => 'glu.h'
	},
);

# need the platform-specific module to find include paths correctly
# see build/lib/SDL/Build/*pm
my $arch          = SDL::Build->get_arch( $^O );

# see which subsystems can be built -- do we have headers for them?
my $build_systems = $arch->find_subsystems( \%subsystems, \%libraries );

# now write SDL::Config
$arch->write_sdl_config( $build_systems );

# and fetch all of the information needed to compile
my $defines       = $arch->build_defines( \%libraries, $build_systems );
my $includes      = $arch->build_includes( \%libraries, $build_systems );
my $links         = $arch->build_links( \%libraries, $build_systems );

# mangle the compilable files into a format Module::Build can understand
my %xs = map { $subsystems{$_}{file}{from} => $subsystems{$_}{file}{to} }
	     keys %subsystems;
my $build   = SDL::Build->new(
	module_name          => 'SDL',
	dist_name            => 'SDL_Perl', 
	license		     => 'lgpl',
	dist_version_from    => 'lib/SDL.pm',
	configure_requires	      =>
	{
		'YAML'	=> '0.68',
		'ExtUtils::CBuilder' => '0.260301',
		'Alien::SDL' => '0.7.1',
	},
	build_requires =>
	{
		'Test::Simple' => '0.47',

	},
	build_recommends     =>
	{
		'Pod::ToDemo'  => '0.20'		
	},
	c_source	     => 'src',
	xs_files             => \%xs,
	meta_add	     =>	     
	{
		no_index =>  { file => [ <make/lib/SDL/*.pm>, <make/lib/SDL/Build/*.pm>, <make/lib/ExtUtils/CBuilder/*>, <make/lib/ExtUtils/*>, <make/lib/ExtUtils/CBuilder/Platform/Windows.pm> ] },
	},
	dist_author	     => 'David J. Goehrig <DGOEHRIG@cpan.org>, Kartik Thakore <KTHAKORE@cpan.org>',
);

if($arch eq 'Darwin')
{
	$build->{c_source} = $arch->build_c_source( \%libraries, $build_systems );
	$build->{c_sources} = $arch->build_c_sources( \%libraries, $build_systems );
	$build->{install_base} = $arch->build_install_base( \%libraries, $build_systems );

}

# and here's where the real (and ugly) magic works... see SDL::Build
$build->set_flags(
	\%subsystems,
	$build_systems,
	$defines,
	$includes,
	$links,
	$sdl_compile_flags,
	$sdl_link_flags,
);
# now we're ready to go!
$build->create_build_script();
