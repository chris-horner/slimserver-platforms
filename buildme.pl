#!/usr/bin/perl -w

use strict;
use warnings;

## Load in certain modules for things we're going to do later...
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec::Functions qw(:ALL);
use Getopt::Long;
use POSIX qw(strftime);

use constant DESTDIR_NOT_REQUIRED => '[not required]';

## Here we set some basic settings.. most of these dont need to change very often.
my $squeezeCenterStartupScript = "server/slimserver.pl";
my $sourceDirsToExclude = ".svn .git .github t tests slimp3 squeezebox /softsqueeze tools ext/source ext-all-debug.js build Firmware/*.bin";
my $revisionTextFile = "server/revision.txt";
my $revision;
my $myVersion = "1.1.0";
my $defaultDestName = "logitechmediaserver";
my $defaultReleaseType = "nightly";

## Windows Specific Stuff
my $windowsPerlDir = "C:\\perl";
my $windowsPerlPath = "$windowsPerlDir\\bin\\perl.exe";

## Directories to exclude when building certain packages...
my $dirsToExcludeForLinuxTarball = "i386-freebsd-64int MSWin32-x86-multi-thread darwin darwin-x86_64 PreventStandby";
my $dirsToExcludeForLinuxPackage = "$dirsToExcludeForLinuxTarball 5.10 5.12 5.14 5.16 5.18";
my $dirsToExcludeForFreeBSDTarball = "MSWin32-x86-multi-thread PreventStandby i386-linux x86_64-linux i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux arm-linux armhf-linux powerpc-linux aarch64-linux icudt46b.dat";
my $dirsToExcludeForARMTarball = "MSWin32-x86-multi-thread PreventStandby i386-linux x86_64-linux i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux i386-freebsd-64int powerpc-linux icudt46b.dat icudt58b.dat";
my $dirsToExcludeForPPCTarball = "MSWin32-x86-multi-thread PreventStandby i386-linux x86_64-linux i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux arm-linux armhf-linux i386-freebsd-64int aarch64-linux icudt46l.dat icudt58l.dat";
my $dirsToExcludeForARMDeb = "$dirsToExcludeForARMTarball 5.10 5.12 5.14 5.16 5.18";
my $dirsToExcludeForx86_64Deb = "5.10 5.12 5.14 5.16 5.18 MSWin32-x86-multi-thread PreventStandby i386-linux i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux arm-linux armhf-linux i386-freebsd-64int powerpc-linux aarch64-linux icudt46b.dat icudt58b.dat";
my $dirsToExcludeFori386Deb = "5.10 5.12 5.14 5.16 5.18 MSWin32-x86-multi-thread PreventStandby x86_64-linux i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux arm-linux armhf-linux i386-freebsd-64int powerpc-linux aarch64-linux icudt46b.dat icudt58b.dat";
my $dirsToExcludeForLinuxNoCpanTarball = "i386-freebsd-64int MSWin32-x86-multi-thread i86pc-solaris-thread-multi-64int darwin darwin-x86_64 i386-linux sparc-linux x86_64-linux arm-linux armhf-linux powerpc-linux aarch64-linux /arch/ PreventStandby";
my $dirsToExcludeForLinuxNoCpanLightTarball = $dirsToExcludeForLinuxNoCpanTarball . " /Bin/ /HTML/! /Firmware/ /MySQL/ Graphics/CODE2000* Plugin/DateTime DigitalInput iTunes LineIn LineOut MusicMagic RSSNews Rescan SavePlaylist SlimTris Snow Plugin/TT/ Visualizer xPL";
my $dirsToIncludeForLinuxNoCpanLightTarball = "EN.*html/images CPAN/HTML";
my $dirsToExcludeForMacOSX = "5.10 5.12 5.14 5.16 5.20 5.22 5.24 5.26 5.28 5.30 5.32 5.36 i386-freebsd-64int i386-linux x86_64-linux x86_64-linux-gnu-thread-multi MSWin32 i86pc-solaris-thread-multi-64int arm-linux armhf-linux powerpc-linux sparc-linux aarch64-linux";
my $dirsToExcludeForWin32 = "5.10 5.12 5.16 5.18 5.20 5.22 5.24 5.26 5.28 5.30 5.32 5.34 5.36 i386-freebsd-64int i386-linux x86_64-linux x86_64-linux-gnu-thread-multi i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux arm-linux armhf-linux powerpc-linux aarch64-linux OS/Debian.pm OS/Linux.pm OS/Unix.pm OS/OSX.pm OS/RedHat.pm OS/Suse.pm OS/SlimService.pm OS/Synology.pm OS/SqueezeOS.pm icudt46b.dat icudt46l.dat icudt58b.dat icudt58l.dat";

# for Docker we provide x86_64 and armhf for Perl 5.32 only
my $dirsToExcludeForDocker = "5.10 5.12 5.14 5.16 5.18 5.20 5.22 5.24 5.26 5.28 5.30 5.34 5.36 MSWin32-x86-multi-thread PreventStandby i386-linux i86pc-solaris-thread-multi-64int darwin darwin-x86_64 sparc-linux i386-freebsd-64int powerpc-linux icudt46b.dat icudt58b.dat";

## Initialize some variables we'll use later
my ($build, $destName, $destDir, $buildDir, $sourceDir, $version, $noCPAN, $fakeRoot, $light, $freebsd, $arm, $ppc, $x86_64, $i386, $releaseType, $release, $tag);

## Generate a random number... used for a single instance wherever we need a temp file.
my $range = 10000;
my $random_number = rand($range);


##############################################################################################
## Begin the main run of the build... based on input from the user, and dynamically	    ##
## picked up content like the version #, we'll build only the appropriate files requested   ##
##############################################################################################
sub main {
	## Find out if the user gave us any data.. if not, post the help and quit
	checkCommandOptions();

	## Get our version #, based on data supplied by user
	$version = getVersion();

	## Right before we start actually building stuff, print out our config options...
	printOptions();

	## Set up the directories we need to do to our build
	setupDirectories();

	## Set the build tree up now... we do this for every distribution we build.
	setupBuildTree();

	## Ok, begin the IF statement... what are we building?
	doCommandOptions();
}

##############################################################################################
## Walk through the options passed in by the user, and see if they make sense. If they      ##
## don't, we'll exit here and show them the usage guidelines.				    ##
##############################################################################################
sub checkCommandOptions {
	## First, lets make sure they sent the most basic option we need, a build target...
	GetOptions(
			'build=s'       => \$build,
			'buildDir=s'    => \$buildDir,
			'sourceDir=s'   => \$sourceDir,
			'destName=s'    => \$destName,
			'destDir=s'     => \$destDir,
			'noCPAN'        => \$noCPAN,
			'freebsd'       => \$freebsd,
			'x86_64'        => \$x86_64,
			'i386'          => \$i386,
			'arm'           => \$arm,
			'ppc'           => \$ppc,
			'light'         => \$light,
			'releaseType=s' => \$releaseType,
			'tag=s'         => \$tag,
			'fakeRoot'      => \$fakeRoot);

	if ( !$build ) {
		showUsage();

		exit(1);
	};

	if ($build =~ /^readynasv2$/) {
		print "Bye, bye ReadyNAS. We're no longer going to build for you. It's time to move on.\n";
		exit(0);
	}

	if ($build =~ /^tarball|docker|debian|rpm|macosx|win32$/) {
		## releaseType is an option, but if its not there, we need
		## to default it to 'nightly'
		if (!$releaseType) {
			$releaseType = "$defaultReleaseType";
		} elsif ( $releaseType ne "nightly" && $releaseType ne "release" ) {
			print "INFO: \$releaseType passed in is incorrect. Please use either \'nightly\' or \'release\'.\n";
		}

		if ($build eq 'docker') {
			$destDir = DESTDIR_NOT_REQUIRED;
		}

		## If they passed in all the options, lets go forward...
		if ($buildDir && $sourceDir && $destDir) {
			print "INFO: Required variables passed in. Moving forward.\n";
			return $build;

		## otherwise, fail and give them the usage guidelines again
		} else {
			print "INFO: Required data missing.\n";
			showUsage();
			exit 1;
		}

	## Now, if they gave us a Build option, but it doesnt make sense... fail
	} else {
		print "INFO: Invalid 'build' option passed in... \n";
		showUsage();
		exit 1;
	}
	return $build;
}

##############################################################################################
## Here we search through the Logitech Media Server startup script to dynamically grab the version  ##
## number for the rest of our script.							    ##
##############################################################################################

sub getVersion {
	## We check the startup script for the version # info on this build. For now, we'll call this
	## the source of truth for the version information.
	my @temparray;
	open(SLIMSERVERPL, "$sourceDir/$squeezeCenterStartupScript") or die "Couldn't open $sourceDir/$squeezeCenterStartupScript to get the version # of this release: $!\n";
	while (<SLIMSERVERPL>) {
		if (/our \$VERSION/) {
			my @temparray = split(/\'/, $_);
			$version = "$temparray[1]";
		}
	}
	close(SLIMSERVERPL);

	if (!$version) {
		die "Couldn't find the version # in $sourceDir/$squeezeCenterStartupScript... aborting built.\n";
	}

	return $version;
}

##############################################################################################
## Begin the main run of the build... based on input from the user, and dynamically	    ##
## picked up content like the version #, we'll build only the appropriate files requested   ##
##############################################################################################
sub printOptions {
	print "INFO: \$buildDir 	-> $buildDir\n";
	print "INFO: \$destDir		-> $destDir\n";
	print "INFO: \$sourceDir	-> $sourceDir\n";
	print "INFO: \$version		-> $version\n";
	print "INFO: \$squeezeCenterStartupScript	-> $sourceDir/$squeezeCenterStartupScript\n";
	print "INFO: \$releaseType	-> $releaseType\n";
}

##############################################################################################
## We need to set up the directories for the build... 					    ##
## 											    ##
##############################################################################################
sub setupDirectories {
	## First, check if the buildDir exists... we need a clean directory to build our code.
	if (-d $buildDir) {
		print "INFO: Source Directory ($buildDir) already existed, erasing it so we can start clean...\n";
		rmtree($buildDir);
	}

	## Now, create a new build directory
	mkpath($buildDir) or die "Problem: couldn't make $buildDir!\n";
	print "INFO: Build Directory ($buildDir) was created...\n";

	## Finally, create the destination directory, if it doesnt exist. We don't care if
	## it exists already, because someone might want to put this into a more generic
	## directory that has other files in it.
	if ($destDir eq DESTDIR_NOT_REQUIRED) {
		print "INFO: Dest Directory is not required, not creating...\n";
	}
	elsif (!-d $destDir) {
		mkpath($destDir) or die "Problem: couldn't make $destDir!\n";
		print "INFO: Dest Directory ($destDir) was created...\n";
	} else {
		print "INFO: Dest Directory ($destDir) already existed, not creating...\n";
	}
}


##############################################################################################
## No matter what we are building, we're going to move it away from the Git source directory##
## and move it into a building directory. 						    ##
##############################################################################################
sub setupBuildTree {
	# Create a copy of the Git source directory without additional
	# directories or .git turd files for the build.

	## Set up directories to exclude when we start the build...
	my @sourceExcludeArray = split(/ /, $sourceDirsToExclude);
	my $sourceExclude = join(' --exclude ', @sourceExcludeArray);

	## If this is created, we need to begin it with '--exclude'... but if it doesnt, do not set it..
	if ($sourceExclude) {
		$sourceExclude = "--exclude $sourceExclude";
	}

	print "INFO: Making copy of server source ($sourceDir -> $buildDir)\n";

	## Exclude the .git directory, and anything else we configured in the beginning of the script.
	print("rsync -a --quiet $sourceExclude $sourceDir/server $sourceDir/platforms $buildDir\n");
	system("rsync -a --quiet $sourceExclude $sourceDir/server $sourceDir/platforms $buildDir");

	## Verify that things went OK during the transfer...
	if (!-d "$buildDir/server") {
		die "Problem: export of server files failed - $buildDir/server directory!";
	}

	## Force some permissions, just in case they weren't already set
	chmod 0755, "$buildDir/$squeezeCenterStartupScript";
	chmod 0755, "$buildDir/server/scanner.pl";
	chmod 0755, "$buildDir/server/gdresized.pl";

	# Write out the revision number
	if ($revision = getRevisionForRepo()) {
		my $date = `date`;

		print "INFO: Last Revision number is: $revision\n";

		open(REV, ">$buildDir/$revisionTextFile") or die "Problem: Couldn't write out $buildDir/$revisionTextFile : $!\n";
		print REV "$revision\n$date";
		close(REV);
	}
}

##############################################################################################
## Assuming everythings worked so far, we'll actually start building the packages. 	    ##
##############################################################################################
sub doCommandOptions {
	## Check if there's a destName passed in
	## $destName is used for Tarballs, Windows and Mac OSX packages. Linux packages
	## have their own naming schemas.

	if (!$destName) {
		$destName = "$defaultDestName-$version-$revision";
	}

	## If we're building a tarball, do the tarball only...
	if ($build eq "tarball") {

		if ( $releaseType && $releaseType eq "release" ) {
			$destName =~ s/-$revision//;
		}

		## If we're building without CPAN libraries, make sure thats in the filename...
		if ($noCPAN && $light) {
			## Use the NO CPAN Light variables
			buildTarball($dirsToExcludeForLinuxNoCpanLightTarball, "$destDir/$destName-noCPAN-light", $dirsToIncludeForLinuxNoCpanLightTarball);
		} elsif ($noCPAN) {
			## Use the NO CPAN variables
			buildTarball($dirsToExcludeForLinuxNoCpanTarball, "$destDir/$destName-noCPAN");
		} elsif ($freebsd) {
			## Don't include Linux binaries
			buildTarball($dirsToExcludeForFreeBSDTarball, "$destDir/$destName-FreeBSD");
		} elsif ($arm) {
			buildTarball($dirsToExcludeForARMTarball, "$destDir/$destName-arm-linux");
		} elsif ($ppc) {
			buildTarball($dirsToExcludeForPPCTarball, "$destDir/$destName-powerpc-linux");
		} else {
			## Use the CPAN variables
			buildTarball($dirsToExcludeForLinuxTarball, "$destDir/$destName");
		}

	} elsif ($build eq "docker") {
		buildDockerImage();

	} elsif ($build eq "debian") {
		## Build a Debian Package
		buildDebian();

	} elsif ($build eq "rpm") {
		## Run the RPM
		buildRPM();

	} elsif ($build eq "macosx") {
		## Build the Mac OSX package
		$destName =~ s/$defaultDestName/LogitechMediaServer/;

		if ( $releaseType && $releaseType eq "release" ) {
			$destName =~ s/-$revision//;
		}

		buildMacOSX("$destName");

	} elsif ($build eq "win32") {
		## Build the Windows 32bit Installer
		$destName =~ s/$defaultDestName/LogitechMediaServer/;
		buildWin32("$destName");

	}
}

##############################################################################################
## We need to know the revision # of the code, so that we can put it into the source tree   ##
##############################################################################################
sub getRevisionForRepo {
	my $revision;
	if (-d "$sourceDir/.svn") {
		open (SVN, "svn info $sourceDir |") or die "Problem: Couldn't run svn info $sourceDir : $!\n";

		while (<SVN>) {
			if (/Last Changed Rev: (\d+)/) {
				$revision = $1;
			}
		}
		close(SVN);
	} elsif (-d "$sourceDir/server/.git") {
		$revision = `git --git-dir=$sourceDir/server/.git log -n 1 --pretty=format:%ct`;
		$revision =~ s/\s*$//s;
	} else {
		$revision = 'UNKNOWN';
	}
	return $revision;
}

##############################################################################################
## display the help
##############################################################################################
sub showUsage {
	print "buildme.pl - version ($myVersion) - Help \n";
	print "-------------------------------------------\n";
	print "This script can build all of our versions \n";
	print "of Logitech Media Server... but only one at a time.\n";
	print "Each distribution has its own options, \n";
	print "listed below... don't try to mix them up! :)\n";
	print " \n";
	print "--- Building a Linux Tarball\n";
	print "    --build tarball <required opts below>\n";
	print "    --buildDir <dir>             - The directory to do temporary work in\n";
	print "    --sourceDir <dir>            - The location of the source code repository\n";
	print "                                   that you've checked out from Git\n";
	print "    --destDir <dir>              - The destination you'd like your files \n";
	print "    --destName <filename>        - The name of the tarball you would like to\n";
	print "       (optional)                  have made. Do not include the .tar.gz/tgz,\n";
	print "                                   it will be appended automatically.\n";
	print "    --freebsd (optional)         - Build a package with only FreeBSD 7.2 binaries\n";
	print "    --arm (optional)             - Build a package with only ARM Linux binaries\n";
	print "    --ppc (optional)             - Build a package with only PPC Linux binaries\n";
	print "    --noCPAN (optional)          - Build a package with no CPAN modules included\n";
	print "    --noCPAN-light (optional)    - Build a package with no CPAN modules, web templates etc. included\n";
	print "\n";
	print "--- Building a Docker image (with only ARM and x86_64 Linux binaries)\n";
	print "    --build docker <required opts below>\n";
	print "    --buildDir <dir>             - The directory to do temporary work in\n";
	print "    --sourceDir <dir>            - The location of the source code repository\n";
	print "                                   that you've checked out from Git\n";
	print "    --releaseType <nightly/release>- Whether you're building a 'release' package, \n";
	print "        (optional)                 or you're building a nightly-style package\n";
	print "    --tag <tag>                  - additional tag for the Docker image\n";
	print "\n";
	print "--- Building an RPM package\n";
	print "    --build rpm <required opts below>\n";
	print "    --buildDir <dir>             - The directory to do temporary work in\n";
	print "    --sourceDir <dir>            - The location of the source code repository\n";
	print "                                   that you've checked out from Git\n";
	print "    --destDir <dir>              - The destination you'd like your files \n";
	print "    --releaseType <nightly/release>- Whether you're building a 'release' package, \n";
	print "        (optional)                 or you're building a nightly-style package\n";
	print "\n";
	print "--- Building a Debian Package\n";
	print "    --build debian <required opts below>\n";
	print "    --buildDir <dir>             - The directory to do temporary work in\n";
	print "    --sourceDir <dir>            - The location of the source code repository\n";
	print "                                   that you've checked out from Git\n";
	print "    --destDir <dir>              - The destination you'd like your files \n";
	print "    --releaseType <nightly/release>- Whether you're building a 'release' package, \n";
	print "        (optional)                 or you're building a nightly-style package\n";
	print "    --fakeroot (optional)        - Whether to use fakeroot to run the build or not. \n";
	print "    --arm (optional)             - Build a package with only ARM Linux binaries\n";
	print "    --x86_64 (optional)          - Build a package with only x86_64 Linux binaries\n";
	print "    --i386 (optional)            - Build a package with only i386 Linux binaries\n";
	print "\n";
	print "--- Building a Mac OSX Package\n";
	print "    --build macosx <required opts below>\n";
	print "    --buildDir <dir>             - The directory to do temporary work in\n";
	print "    --sourceDir <dir>            - The location of the source code repository\n";
	print "                                   that you've checked out from Git\n";
	print "    --destDir <dir>              - The destination you'd like your files \n";
	print "    --destName <filename>        - The name of the OSX Package Name, do not \n";
	print "       (optional)                  include the .dmg\n";
	print "\n";
	print "--- Building a Windows Package\n";
	print "    --build win32 <required opts below>\n";
	print "    --buildDir <dir>             - The directory to do temporary work in\n";
	print "    --sourceDir <dir>            - The location of the source code repository\n";
	print "                                   that you've checked out from Git\n";
	print "    --destDir <dir>              - The destination you'd like your files \n";
}

sub removeExclusions {
	my ($dirsToExclude, $dirsToInclude) = @_;

	## First, lets make sure we get rid of the files we don't need for this install
	my @dirsToExclude = split(/ /, $dirsToExclude);
	my $n = 0;

	$dirsToInclude ||= '';
	if ($dirsToInclude) {
		$dirsToInclude =~ s/ /\|/g;
		$dirsToInclude = "| grep -v -E '$dirsToInclude'" if $dirsToInclude;
	}

	while ($dirsToExclude[$n]) {
		my $doInclude = '';

		# exclusions with a trailing ! should respect inclusions
		if ($dirsToExclude[$n] =~ s/!$//) {
			$doInclude = $dirsToInclude;
		}

		print "INFO: Removing $dirsToExclude[$n] files from buildDir...\n";
		system("find $buildDir -depth | grep '$dirsToExclude[$n]' $doInclude | xargs rm -rf > /dev/null 2>&1");
		$n++;
	}
}

##############################################################################################
## Build Docker image                                                                       ##
##############################################################################################
sub buildDockerImage {
	removeExclusions($dirsToExcludeForDocker);

	my $dockerDir = "$buildDir/platforms/Docker";
	my $workDir = "$buildDir/server";

	## Make the image...
	print "INFO: Building Docker image with source from $workDir...\n";
	system("cp $dockerDir/.dockerignore $dockerDir/* $workDir");

	my @tags = ("$version");
	$tag ||= "latest" if $releaseType eq "release";
	push @tags, $tag if $tag;

	my $tags = join(' ', map {
		"--tag lmscommunity/logitechmediaserver:$_";
	} @tags);

	system("cd $workDir; docker buildx build --push --platform linux/arm/v7,linux/amd64,linux/arm64/v8 $tags .");

	die('Docker build failed') if $? & 127;
}

##############################################################################################
## Here we can build a no-cpan tarball, if we either need one, or the user calls for one    ##
##############################################################################################
sub buildTarball {
	my ($dirsToExclude, $tarballName, $dirsToInclude) = @_;

	## Grab the variables passed to us...
	if ( ($dirsToExclude && $tarballName) || die("Problem: Not all of the variables were passed to the BuildTarball function...") ) {

		removeExclusions($dirsToExclude, $dirsToInclude);

		## We want a pretty name as the output dir, so we rename the server directory real quick
		## (the old script would do an rsync here, but an rsync takes too long and is an unnecessary waste of space, even temorarily)
		my ($name, $path, $suffix) = fileparse($tarballName);
		system("mv $buildDir/server $buildDir/$name");

		## Make the tarball...
		print "INFO: Building $tarballName.tgz with source from $buildDir/$name ($buildDir/server), excluding [$dirsToExclude]...\n";
		system("cd $buildDir; tar -zcf $tarballName.tgz $name");

		## Remove the link
		system("mv $buildDir/$name $buildDir/server");
	}
}

##############################################################################################
## Build an RPM package									    ##
##############################################################################################
sub buildRPM {
	require File::Which;

	print "INFO: Building YUM-ified RPM for RHEL/RedHat/Fedora/etc... \n";

        # this must be a unix system
        # make the RPM if appropriate

        if (!File::Which::which('rpmbuild')) {

                print "rpmbuild not detected on this system. Not making an RPM";
                return;
        }

	print "INFO: Building xxx RPM in $buildDir... final file will be in $destDir. \n";

	## We need to setup an RPM build directory to put all of our files in...
	for my $path (qw(SPECS SOURCES BUILD RPMS SRPMS)) {
		print "INFO: Making directory for RPM build... ($buildDir/rpm/$path)\n";
		mkpath("$buildDir/rpm/$path") || die "PROBLEM: I couldn't create $buildDir/rpm/$path...\n";
	}

	## Now we need to build a tarball ...
	print "INFO: Building $buildDir/$defaultDestName.tgz for the RPM...\n";

	# CentOS 7 is still supported till 2024 - put 5.16 back in...
	$dirsToExcludeForLinuxPackage =~ s/5\.16 //;

	buildTarball($dirsToExcludeForLinuxPackage, "$buildDir/$defaultDestName");

	## We already built a tarball, so now lets use it...
	print "INFO: Moving $buildDir/$defaultDestName.tgz to $buildDir/rpm/SOURCES...\n";
	system("mv $buildDir/$defaultDestName.tgz $buildDir/rpm/SOURCES");

	## Copy the various SPEC< Config, etc files into the right dirs...
        copy("$buildDir/platforms/redhat/squeezeboxserver.config", "$buildDir/rpm/SOURCES");
        copy("$buildDir/platforms/redhat/squeezeboxserver.init", "$buildDir/rpm/SOURCES");
        copy("$buildDir/platforms/redhat/squeezeboxserver.logrotate", "$buildDir/rpm/SOURCES");
        copy("$buildDir/platforms/redhat/squeezeboxserver.service", "$buildDir/rpm/SOURCES");
        copy("$buildDir/platforms/redhat/README.systemd", "$buildDir/rpm/SOURCES");
        copy("$buildDir/platforms/redhat/squeezeboxserver.spec", "$buildDir/rpm/SPECS");

	## Just check, if this is a 'nightly' build, pass on 'trunk' to the rpmbuild command
	if ($releaseType eq "nightly") {
		$releaseType = "trunk";
	}

        # Do it
        my $date = strftime('%Y-%m-%d', localtime());
        print `rpmbuild -bb --with $releaseType --define="src_basename $defaultDestName" --define="_version $version" --define="_src_date $date" --define="_revision $revision" --define='_topdir $buildDir/rpm' $buildDir/rpm/SPECS/squeezeboxserver.spec`;

	## Just move the file out of the building directory, and put it into the destDir
	print "INFO: Moving $buildDir/rpm/RPMS/noarch/*.rpm to $destDir\n";
	system("mv $buildDir/rpm/RPMS/noarch/*.rpm $destDir");

	rmtree("$buildDir/rpm");
}


##############################################################################################
## Build a Debian package								    ##
##############################################################################################
sub buildDebian {
	print "INFO: Building package for Debian Release... \n";

	my $suffix;
	if ($arm) {
		print "INFO: This is an ARM Debian build.\n";
		removeExclusions($dirsToExcludeForARMDeb);
		$suffix = 'arm';
	}
	elsif ($x86_64) {
		print "INFO: This is a x86_64 Debian build.\n";
		removeExclusions($dirsToExcludeForx86_64Deb);
		$suffix = 'amd64';
	}
	elsif ($i386) {
		print "INFO: This is an i386 Debian build.\n";
		removeExclusions($dirsToExcludeFori386Deb);
		$suffix = 'i386';
	}
	else {
		removeExclusions($dirsToExcludeForLinuxPackage);
	}

	## Lets setup the right version/build #...
	open (READ, "$sourceDir/platforms/debian/changelog") || die "Can't open changelog file to read: $!\n";
	open (WRITE, ">$buildDir/platforms/debian/changelog") ||  die "Can't open changelog file to write: $!\n";

	## Unlike the RPM, with a Debian package there's no simple way to go from a
	## 'release' to a 'nightly.' We need to make that choice here, and update
	## the changelog file accordingly.

	if ($releaseType eq "nightly") {
		$release = "$version~$revision";
	} elsif ($releaseType eq "release") {
		$release = "$version";
	}

	while (<READ>) {
		s/_VERSION_/$release/;
		print WRITE $_;
	}

	close WRITE;
	close READ;

	## Ok, we've set everything up... lets run the dpkg-buildpkg command...
	if ($fakeRoot) {
		print `cd $buildDir/platforms; fakeroot dpkg-buildpackage -b -d ;`;
	} else {
		print `cd $buildDir/platforms; dpkg-buildpackage -b -d ;`;
	}

	if ($suffix) {
		my ($old) = glob("$buildDir/*all.deb");
		my $new = $old;
		$new =~ s/_all\.deb/_$suffix.deb/;
		rename $old, $new;
	}

	## Now that the package is built, lets put it into the destDir
	system("mv -f $buildDir/*.deb $destDir");

}


##############################################################################################
## Build the Mac OSX Installer Package
##############################################################################################
sub buildMacOSX {
	## Grab the variables passed to us...
	if ( ($_[0] ) || die("Problem: Not all of the variables were passed to the buildMacOSX function...") ) {
		## Take the filename passed to us and make sure that we build the DMG with
		## that name, and that the 'pretty mounted name' also matches
		my $pkgName = $_[0];

		print "INFO: Building package for Mac OSX (Universal)... \n";

		## First, lets make sure we get rid of the files we don't need for this install
		my @dirsToExclude = split(/ /, $dirsToExcludeForMacOSX);
		my $n = 0;
		while ($dirsToExclude[$n]) {
			print "INFO: Removing $dirsToExclude[$n] files from buildDir...\n";
			system("find $buildDir | grep -i $dirsToExclude[$n] | xargs rm -rf ");
			$n++;
		}

		## Now, lets make the Install Files directory
		print "INFO: Making $buildDir/$pkgName/Install Files...\n";
		mkpath("$buildDir/$pkgName/Install Files");

		## Copy in the documentation and license files..
		print "INFO: Copying documentation & licenses...\n";
		copy("$buildDir/server/license.txt", "$buildDir/$pkgName/License.txt");

		## Set some xcodebuild paths...
		my $xcodeBuildDir = "$buildDir/platforms/osx/Preference Pane/build/Deployment";
		my $prefPaneDir = "$buildDir/$pkgName/Install Files/Squeezebox.prefPane";
		my $contentsDir = "$prefPaneDir/Contents";

		## Lets build the pref pane and installer...
		print "INFO: Beginning PreferencePane and Installer build...\n";
		system("cd \"$buildDir/platforms/osx/Preference Pane\"; xcodebuild -project \"SqueezeCenter.xcodeproj\" -target \"Squeezebox\" -configuration Deployment");

		print "INFO: Copying Preference Pane...\n";
		system("ditto \"$xcodeBuildDir/Squeezebox.prefPane\" \"$prefPaneDir\"");

		system("mv \"$buildDir/server\" \"$contentsDir/\" ");
		system("cd \"$contentsDir\"; mkdir perl; cd perl; tar xjf \"$buildDir/platforms/osx/Perl-5.34.0-x86_64-arm64.tar.bz2\"; chmod a+x bin/perl");

		print "INFO: Create installer package $pkgName...\n";
		system("/Developer/usr/bin/packagemaker --verbose --root-volume-only --root \"$prefPaneDir\" --scripts \"$buildDir/platforms/osx/Installer/scripts\" --out \"$destDir/$pkgName.pkg\" --target 10.5 --domain system --id com.logitech.music.Squeezebox --version 1.0 --resources \"$buildDir/platforms/osx/Installer/l10n\" --title \"Logitech Media Server\"");

		# add localized resource files to the package
		print "\nINFO: Add localized resource files to package...\n";

		rmtree("$buildDir/lms_tmp");

		# we need to manually modify the Distribution file in the package to make it recognize the localizations - known bug in packagemaker
		system("pkgutil --expand \"$destDir/$pkgName.pkg\" $buildDir/lms_tmp");

		require File::Slurp;

		my $distributionXML = File::Slurp::read_file("$buildDir/lms_tmp/Distribution");
		$distributionXML =~ s/(<\/title>)/$1\n<welcome file="Welcome"\/>\n<background file="background" alignment="topleft" scaling="none"\/>/;
		$distributionXML =~ s/(<choice) /$1 customLocation="\/Library\/PreferencePanes" /;
		File::Slurp::write_file("$buildDir/lms_tmp/Distribution", $distributionXML);

		opendir my ($dirh), "$buildDir/lms_tmp/Resources/";

		# copy the background image in each localization's folder
		for ( readdir $dirh ) {
			my $f = "$buildDir/lms_tmp/Resources/$_";
			if ( $f =~ /\.lproj$/i && -d $f ) {
				copy("$buildDir/platforms/osx/Installer/installer_osx.png", "$f/background");
			}
		}

		closedir $dirh;

		system("pkgutil --flatten $buildDir/lms_tmp \"$destDir/$pkgName-unsigned.pkg\"");

		if ($releaseType eq 'release') {
			unlink("$destDir/$pkgName.pkg");
		}
		else {
			move("$destDir/$pkgName-unsigned.pkg", "$destDir/$pkgName.pkg");
		}
	}
}

##############################################################################################
## Build the Windows32 Installer
##############################################################################################
sub buildWin32 {
	## Grab the variables passed to us...
	if ( ($_[0] ) || die("Problem: Not all of the variables were passed to the BuildWin32 function...") ) {
		## Take the filename passed to us and make sure that we build the DMG with
		## that name, and that the 'pretty mounted name' also matches
		my $destFileName = $_[0];

		if ( $releaseType && $releaseType eq "release" ) {
			$destFileName =~ s/-$revision//;
		}

		print "INFO: Building Win32 Installer Package...\n";

		## First, lets make sure we get rid of the files we don't need for this install
		my @dirsToExclude = split(/ /, $dirsToExcludeForWin32);
		my $n = 0;
		while ($dirsToExclude[$n]) {
			print "INFO: Removing $dirsToExclude[$n] files from buildDir...\n";
			system("find $buildDir | grep -i $dirsToExclude[$n] | xargs rm -rf ");
			$n++;
		}

		print "INFO: Creating $buildDir/build for the final packaging...\n";
		mkpath("$buildDir/build");

		print "INFO: Copying server directory to $buildDir/build...\n";
		system("cp -R $buildDir/server \"$buildDir/build/server\" ");

		print "INFO: Copying various documents to $buildDir/build...\n";
		copy("$buildDir/server/CHANGELOG.html", "$buildDir/build/Release Notes.html");
		copy("$buildDir/server/license.txt", "$buildDir/build/License.txt");

		# This used to copy Wx code into the system Perl dir, this shouldn't be done in a build script
		#print "INFO: Copying additional perl modules to $windowsPerlDir\\site...\n";
		#system("cp -R $buildDir/platforms/win32/lib/perl5/* \"$windowsPerlDir/site\" ");

		my $rev = int(($revision || getRevisionForRepo() || $version) / 3600) % 65536;
		my @versionInfo = (
			"CompanyName=Logitech Inc.",
			"FileVersion=$rev",
			"LegalCopyright=Copyright 2001-2020 Logitech Inc.",
			"ProductVersion=$version",
			"ProductName=Logitech Media Server",
		);


		print "INFO: Building SqueezeTray executable...\n";

		my $programInfo = join(';', @versionInfo, (
			"FileDescription=Logitech Media Server Tray Icon",
			"OriginalFilename=SqueezeTray",
			"InternalName=SqueezeTray",
		));

		system("cd $buildDir/platforms/win32; perltray --perl \"$windowsPerlPath\" --info \"$programInfo\" SqueezeTray.perltray");
		move("$buildDir/platforms/win32/SqueezeTray.exe", "$buildDir/build/SqueezeTray.exe");
		copy("$buildDir/platforms/win32/strings.txt", "$buildDir/build/strings.txt");

		print "INFO: Building Logitech Media Server Service Helper executable...\n";


		$programInfo = join(';', @versionInfo, (
			"FileDescription=Logitech Media Server Service Helper",
			"OriginalFilename=squeezesvc",
			"InternalName=squeezesvc",
		));

		system("cd $buildDir/platforms/win32; perlapp --perl \"$windowsPerlPath\" --info \"$programInfo\" --clean --bind=grant.exe[file=../../server/Bin/MSWin32-x86-multi-thread/grant.exe,mode=666] --force squeezesvc.pl");
		move("$buildDir/platforms/win32/squeezesvc.exe", "$buildDir/build/server/squeezesvc.exe");


		print "INFO: Building Logitech Media Server executable for server...\n";

		$programInfo = join(';', @versionInfo, (
			"FileDescription=Logitech Media Server",
			"OriginalFilename=SqueezeboxServer",
			"InternalName=SqueezeboxServer",
		));

		system("cd $buildDir/server; perlsvc --perl \"$windowsPerlPath\" --info \"$programInfo\" --verbose ../platforms/win32/squeezecenter.perlsvc");
		move("$buildDir/server/slimserver.exe", "$buildDir/build/server/SqueezeSvr.exe");


		print "Making scanner executable...\n";

		$programInfo = join(';', @versionInfo, (
			"FileDescription=Logitech Media Server Scanner",
			"OriginalFilename=Scanner",
			"InternalName=Scanner",
		));

		system("cd $buildDir/server; perlapp --perl \"$windowsPerlPath\" --info \"$programInfo\" ../platforms/win32/scanner.perlapp");
		move("$buildDir/server/scanner.exe", "$buildDir/build/server/scanner.exe");


		print "Making control panel executable...\n";

		$programInfo = join(';', @versionInfo, (
			"FileDescription=Logitech Media Server Control Panel",
			"OriginalFilename=Cleanup",
			"InternalName=Cleanup",
		));

		system("cd $buildDir/server; perlapp --perl \"$windowsPerlPath\" --info \"$programInfo\" ../platforms/win32/cleanup.perlapp");
		move("$buildDir/server/cleanup.exe", "$buildDir/build/server/squeezeboxcp.exe");


		print "INFO: Removing files we don't want to have in the binary distribution...\n";
		rmtree("$buildDir/build/server/CPAN");
		rmtree("$buildDir/build/server/lib");

		foreach (qw(Buttons Control Display Formats GUI Hardware Media Menu Music Networking Player Schema Utils Web)) {
			rmtree("$buildDir/build/server/Slim/$_");
		}

		unlink("$buildDir/build/server/Slim/Plugin/Base.pm");
		unlink("$buildDir/build/server/Slim/Plugin/OPMLBased.pm");
		unlink("$buildDir/build/server/Slim/bootstrap.pm");
		unlink("$buildDir/build/server/Slim/Formats.pm");
		unlink("$buildDir/build/server/Slim/Schema.pm");
		unlink("$buildDir/build/server/cleanup.pl");
		unlink("$buildDir/build/server/slimserver.pl");
		unlink("$buildDir/build/server/slimservice.pl");
		unlink("$buildDir/build/server/scanner.pl");


		print "INFO: Making installer...\n";

		copy("$buildDir/platforms/win32/installer/ServiceManager.iss", "$buildDir/build");
		copy("$buildDir/platforms/win32/installer/SocketTest.iss", "$buildDir/build") || die ($!);
		copy("$buildDir/platforms/win32/installer/strings.iss", "$buildDir/build");
		copy("$buildDir/platforms/win32/installer/psvince.dll", "$buildDir/build");
		copy("$buildDir/platforms/win32/installer/sockettest.dll", "$buildDir/build");
		copy("$buildDir/platforms/win32/installer/ApplicationData.xml", "$buildDir/build");
		copy("$buildDir/platforms/win32/lib/vcredist.exe", "$buildDir/build");

		copy("$buildDir/platforms/win32/InnoSetup/Languages/Danish.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Dutch.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Default.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Finnish.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/French.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/German.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Hebrew.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Italian.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Norwegian.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Spanish.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Czech.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Polish.isl", "$buildDir/build");
		copy("$buildDir/platforms/win32/InnoSetup/Languages/Russian.isl", "$buildDir/build");
		# Swedish is 3rd party - we keep it in our installer folder
		copy("$buildDir/platforms/win32/installer/Swedish.isl", "$buildDir/build");

		copy("$buildDir/platforms/win32/installer/logitech.bmp", "$buildDir/build");
		copy("$buildDir/platforms/win32/installer/squeezebox.bmp", "$buildDir/build");

		# replacing build number in installer script
		system("sed -e \"s/VersionInfoVersion=0.0.0.0/VersionInfoVersion=$rev/\" \"$buildDir/platforms/win32/installer/SqueezeCenter.iss\" > \"$buildDir/build/SqueezeCenter.iss\"");
		system("cd $buildDir/build; \"$buildDir/platforms/win32/InnoSetup/ISCC.exe\" \/Q SqueezeCenter.iss ");

		unlink("$buildDir/build/SqueezeCenter.iss");
		unlink("$buildDir/build/ServiceManager.iss");
		unlink("$buildDir/build/SocketTest.iss");
		unlink("$buildDir/build/StartupModeWizardPage.iss");
		unlink("$buildDir/build/ServiceEnabler.iss");

		unlink("$buildDir/build/psvince.dll");
		unlink("$buildDir/build/sockettest.dll");
		unlink("$buildDir/build/ApplicationData.xml");
		unlink("$buildDir/build/slim.bmp");
		unlink("$buildDir/build/strings.iss");

		unlink("$buildDir/build/Danish.isl");
		unlink("$buildDir/build/Default.isl");
		unlink("$buildDir/build/Dutch.isl");
		unlink("$buildDir/build/English.isl");
		unlink("$buildDir/build/Finnish.isl");
		unlink("$buildDir/build/French.isl");
		unlink("$buildDir/build/German.isl");
		unlink("$buildDir/build/Hebrew.isl");
		unlink("$buildDir/build/Norwegian.isl");
		unlink("$buildDir/build/Italian.isl");
		unlink("$buildDir/build/Spanish.isl");
		unlink("$buildDir/build/Swedish.isl");
		unlink("$buildDir/build/Czech.isl");
		unlink("$buildDir/build/Polish.isl");
		unlink("$buildDir/build/Russian.isl");


		print "INFO: Making Windows Home Server installer... $version.$revision \n";
		# replacing build number in installer script
		system("sed -e \"s/!!revision!!/$revision/\" \"$buildDir/platforms/win32/installer/SqueezeCenter.wxs\" > \"$buildDir/build/Output/SqueezeCenter.wxs\"");
		copy("$buildDir/platforms/win32/WHS Add-In/SqueezeCenter/bin/Release/HomeServerConsoleTab.SqueezeCenter.dll", "$buildDir/build/Output");
		copy("$buildDir/platforms/win32/WHS Add-In/SqueezeCenter/bin/Release/Jayrock.Json.dll", "$buildDir/build/Output");
		system("cd $buildDir/build/Output; \"$buildDir/platforms/win32/WiX/candle.exe\" SqueezeCenter.wxs");
		system("cd $buildDir/build/Output; \"$buildDir/platforms/win32/WiX/light.exe\" -sw2024 -sw1076 SqueezeCenter.wixobj");

		unlink("$buildDir/build/Output/SqueezeCenter.wixobj");
		unlink("$buildDir/build/Output/SqueezeCenter.wixpdb");
		unlink("$buildDir/build/Output/SqueezeCenter.wxs");
		unlink("$buildDir/build/Output/HomeServerConsoleTab.SqueezeCenter.dll");

		print "INFO: Everything is finally ready, renaming the .exe and zip files...\n";
		print "INFO: Moving [$buildDir/build/Output/SqueezeSetup.exe] to [$destDir/$destFileName.exe]\n";
		move("$buildDir/build/Output/SqueezeSetup.exe", "$destDir/$destFileName.exe");

		# rename the Windows Home Server installer
		print "INFO: Moving [$buildDir/build/Output/SqueezeCenter.msi] to [$destDir/$destFileName-whs.msi]\n";
		move("$buildDir/build/Output/SqueezeCenter.msi", "$destDir/$destFileName-whs.msi");

		rmtree("$buildDir/build/Output");
	}
}

##i############################################################################################
## Ok, start the main() function and begin everything...				    ##
##############################################################################################
main();
