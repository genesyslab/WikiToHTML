#!/usr/local/bin/perl
#
# Purpose: To generate static HTML from http://docs.genesys.com (ie: $sourceurl).
# Usage: WikiToHTML.pl -p <product> [-v <version> [-m <manual>]] [-u <username> <password>] [-div|-frames]
# Comments: 
# 	* username and password parameters are optional, but required to generate HTML from closed content (NOT IMPLEMENTED YET)
# 	* script returns content for exactly one product, but multiple versions/manuals can be specified if desired
# 	* not providing a version and/or manual via command line will cause all versions and/or manuals (respectively) to be processed
# 	* obviously, perl must be installed on your computer before running this script

use feature "switch";
use WWW::Mechanize;
use LWP::Simple;
use HTTP::Cookies;
use File::Basename;
use File::Slurp;

# initialize variables
$baseurl = "docs.genesys.com"; $subwiki = "";				# default value of base url is our main docs.genesys.com site; no subwiki by default
$product = ''; @version = (); @manual = ();							# basic variables to track the product/versions/manuals being converted to static HTML
$username = ''; $password = '';										# only required if logging in to wiki (NOT IMPLEMENTED YET)
$formatting = 'frames'; $divopen = ''; $divclose = '';				# variables to support different types of formatting; allowable values: none, div, frames
$url = ''; @pagelist = (); $pagecontent = ''; $searchstring = '';	# variables used with WWW::Mechanize to get/process web content
$basePath = "Wiki_HTML"; $filename = ''; $filecount=0;				# variables to handle file/folder creation
@imagelist = (); $imagename = '';									# list of images used in convereted docs, to be copied locally and have paths adjusted
$stylecount = 1; $styles = '';	$openHTML = ''; $closeHTML = ''; 	# variables use to track and manage stylesheets in generated files
$skin = 'none';														# could allow different skins in future instead of &action=render (based on &useskin=help)

# set values based on command line parameters
$argnum = 0;
# disable experimental warnings for given/when statement
no warnings 'experimental::smartmatch';
# autoflush stdout so that printed status updates are displayed nicely
local $| = 1;

print "---------------------------------------------\n";
print "--  Wiki to HTML Conversion Script v1.5   ---\n";
print "---------------------------------------------\n\n";

while ($argnum <= $#ARGV){
	given ($ARGV[$argnum]){
		when ("-p") {$product=$ARGV[++$argnum];}
		when ("-v") {push(@version, $ARGV[++$argnum]);}
		when ("-m") {push(@manual, $ARGV[++$argnum]);}
		when ("-u") {$username=$ARGV[++$argnum]; $password=$ARGV[++$argnum];}
		when ("-div") {$formatting = 'div';}
		when ("-noframes") {$formatting = 'none';}
		when ("-skin") {$skin=$ARGV[++$argnum];}
		when ("-baseurl") {$baseurl=$ARGV[++$argnum];}
		when ("-subwiki") {$subwiki=$ARGV[++$argnum];}
	}
	$argnum++;
}

# build base URL: two parameters, first to provide the domain (ex: "docs.genesys.com") and the second to provide any subwiki details (ex: "/i18n/DEU")
$sourceurl = $baseurl . $subwiki;

# confirm that product has some value; exit script otherwise
if ($product eq '') {
	print "\nInvalid command line paramters.  Expected usage: \n";
	print "    WikiToHTML.pl -p <product> [-v <version>] [-m <manual>] [-u <username> <password>] [-div|-frames] [-baseurl <url>] [-subwiki <subwiki>]";
	print "\n---------------------------------------------\n";
	exit;
}
# establish web connection
$mech = WWW::Mechanize->new();
# log in to the wiki (only if credentials were provided)
if ($username ne '') {

	#-----------------------------------------------
	# print a heads-up of what's happening
	print "Attempting to log in.\n";
	#-----------------------------------------------

	$url ='http://' . $sourceurl . '/index.php?title=Special:UserLogin';
	if (get_url()){
		# key login form details: wpName=username, wpPassword=password, wpLoginAttempt to submit
		$mech->form_name("userlogin");
		$mech->set_fields(wpName=>$username, wpPassword=>$password);
		$response = $mech->click_button(name=>'wpLoginAttempt');
	}
	# check: did login work?  if not, abort process
	# ...
}
else {
	print "Warning: No login details provided.\nRestricted and unreleased content will not be generated.\n";
}
# confirm that we have at least one version/manual; if not, populate with full list from wiki
if (scalar(@version)==0) {
	# retrieve versions page for specified product
	#-----------------------------------------------
	# print a heads-up of what's happening
	print "Getting a list of versions.\n";
	#-----------------------------------------------
	$url = 'http://' . $sourceurl . '/index.php?title=Documentation:' . $product . ':Versions&action=render';
	if (get_url()){
		# create a list of versions from the page content
		@version = ( $pagecontent =~ /<p>Version\ (.*)\ \(/g );
	}
	else{
		print "Warning: Unable to retrieve a list of versions.\n";
		exit;
	}
}
if (scalar(@manual)==0) {
	# retrieve manuals page for specified product
	#-----------------------------------------------
	# print a heads-up of what's happening
	print "Getting a list of manuals.\n";
	#-----------------------------------------------
	$url = 'http://' . $sourceurl . '/index.php?title=Documentation:' . $product . ':Manuals&action=render';
	if (get_url()){
		# create a list of manuals from the page content
		$searchstring = 'Documentation:' . $product . ':(.*)TOC';
		@manual = ( $pagecontent =~ /$searchstring/g );	
	}
	else{
		print "Warning: Unable to retrieve a list of manuals.\n";
		exit;
	}
}

#-----------------------------------------------
# print a heads-up of what's going to be created
print "\nContent Selected: ";
print "\n    product: " . $product;
print "\n    version(s): ";
print join(", ", @version);
print "\n    manual(s): ";
print join(", ",@manual);
print "\n";
#-----------------------------------------------

#-----------------------------------------------
# print a heads-up of what's being processed
print "\nBuilding folder structure.\n";
#-----------------------------------------------

# build folder structure (can ignore folder creation errors; just need to be sure they exist)
mkdir $basePath;
mkdir $basePath . "\\" . $product;
# create copies of our arrays so they can be processed twice without issue
@tempversion=@version; @tempmanual=@manual;

#-----------------------------------------------
# print a heads-up of what's being processed
print "\nNow Processing Guides\nPlease be patient - this may take several minutes.\n";
#-----------------------------------------------

foreach my $curversion (@version){
	# build folder for the current version
	mkdir $basePath . "\\" . $product . "\\" . $curversion;
	foreach my $curmanual (@manual){

		#-----------------------------------------------
		# print a heads-up of the version/manual being processed
		print "\n    $curmanual $curversion: ";
		#-----------------------------------------------		
		
		# build folder structure for the current manual
		mkdir $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual;
		mkdir $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\images";
		mkdir $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\styles";
		# ED: should build these paths dynamically based on CSS images used in the specified skin
		mkdir $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\styles\\images";
		mkdir $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\styles\\images_redesign";

		#-----------------------------------------------
		# print a heads-up of what's being processed
		print "\n      Creating stylesheets and JavaScript\n";
		#-----------------------------------------------
		
		if ($skin ne 'none'){
			# get CSS from the selected skin
			$url = 'http://' . $sourceurl . '/skins/' . $skin . '/main.css';
			if (get_url()){
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\main.css';
				write_file();
			}
		}
		else {
			# if using &action=render then use this default skin
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\main.css';
			$pagecontent = read_file('default_style.css');
			write_file();
		}
		# get images from the main.css file
		$searchstring = 'url\((.*)\)';
		@imagelist = ( $pagecontent =~ /$searchstring/g );
		# copy the images to a local folder
		foreach $curimage (@imagelist){
			$curimage =~ s/"//g;
			# check for images from the skin folder
			if ($skin ne 'none') {
				$status = getstore("http://" . $sourceurl . "/skins/" . $skin . "/" . $curimage, $basePath . '/' . $product . '/' . $curversion . '/' . $curmanual . '/styles/' . $curimage);
			}
			else {
				# note: default skin is based on help skin; try drawing images there
				$status = getstore("http://" . $sourceurl . "/skins/help/" . $curimage, $basePath . '/' . $product . '/' . $curversion . '/' . $curmanual . '/styles/' . $curimage);
			}
			# if image not found under skin folder, check under ponydocs skin
			if (!is_success($status)){
				getstore("http://" . $sourceurl . "/skins/ponydocs/" . $curimage, $basePath . '/' . $product . '/' . $curversion . '/' . $curmanual . '/styles/' . $curimage);
			}
		}
		# string to add CSS to all pages being created
		$styles = '	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />' . "\n";
		$styles = $styles . '	<link rel="stylesheet" href="./styles/main.css" type="text/css"/>' . "\n";
		# add JavaScript required for toggledisplay
		$styles = $styles . '	<!-- Adding ToggleDisplay JavaScript -->
		<script type="text/javascript">
		function toggleDisplay( id, hidetext, showtext ) {
				link = document.getElementById( id + "l" ).childNodes[0];
				with( document.getElementById( id ).style ) {
						if( display == "none" ) {
								display = "inline";
								link.nodeValue = hidetext;
						} else {
								display = "none";
								link.nodeValue = showtext;
						}
				}
		}
		</script>';
		# add JavaScript for Tabber extension
		$url = 'http://' . $sourceurl . '/extensions/Tabber/Tabber.js';
		if (get_url()){
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\Tabber.js';
			write_file();
		}
		$url = 'http://' . $sourceurl . '/extensions/Tabber/Tabber.css';
		if (get_url()){
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\Tabber.css';
			write_file();
		}
		# add JavaScript for MultiStep extension
		$url = 'http://' . $sourceurl . '/extensions/MultiStep/scripts/jquery-1.10.2.min.js';
		if (get_url()){
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\Multistep_a.js';
			write_file();
		}
		$url = 'http://' . $sourceurl . '/extensions/MultiStep/scripts/jquery-migrate-1.2.1.min.js';
		if (get_url()){
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\Multistep_b.js';
			write_file();
		}
		$url = 'http://' . $sourceurl . '/extensions/MultiStep/scripts/main.js';
		if (get_url()){
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\Multistep_main.js';
			write_file();
		}
		$url = 'http://' . $sourceurl . '/extensions/MultiStep/css/styles.css';
		if (get_url()){
			$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . '\\styles\\Multistep.css';
			write_file();
		}
		$styles = $styles . '
		<!-- Adding Multistep Styles/Javascript -->
		<link rel="stylesheet" href="./styles/Multistep.css" />
		<script type="text/javascript" src="./styles/MultiStep_a.js"></script>
		<script type="text/javascript" src="./styles/MultiStep_b.js"></script>
		<script type="text/javascript" src="./styles/MultiStep_main.js"></script>';
		
		# set up the $styles variable to hold opening HTML code
		$openHTML = "<html>\n\n<head>\n" . $styles . "\n</head>\n\n<body>\n";
		$closeHTML = "</body>\n\n</html>";

		#-----------------------------------------------
		# print a heads-up of what's being processed
		print "      Building TOC ";
		#-----------------------------------------------

		# retrieve TOC for specified product/version/manual
		$url = 'http://' . $sourceurl . '/index.php?title=Documentation:' . $product . ':' . $curmanual . 'TOC' . $curversion . '&action=render';
		# try to get the specified TOC page, and only continue if a TOC exists for the product/version/manual combination
		if (get_url()){
			# remove any comments to avoid picking up bad pages
			$pagecontent =~ s/<!--(?:.*)-->/<!-- -->/g;
			# create a list of page names from the TOC page content
			$searchstring = '<a href="' . $subwiki . '/Documentation:' . $product . ':' . $curmanual . ':(.*):' . $curversion . '">';
			@pagelist = ( $pagecontent =~ /$searchstring/g );
			@temppagelist = @pagelist;

			#-----------------------------------------------
			# print a heads-up of what's being processed
			print "(" . scalar(@pagelist) . " wiki pages found)\n";
			#-----------------------------------------------

			# clean up links to other pages
			$searchstring = '<a href="[http:\/\/docs\.genesys\.com\/]*' . $subwiki . '/Documentation:' . $product . ':' . $curmanual . ':';
			$pagecontent =~ s/$searchstring/<a href="/g;
			$searchstring = ':' . $curversion . '">';
			if ($formatting eq 'frames'){
				$pagecontent =~ s/$searchstring/.html" target="content">/g;
			}
			else{
				$pagecontent =~ s/$searchstring/.html">/g;
			}
			# save two copies of $pagecontent so that we can search and replace page names in links with H1 headers while processing; we will then revisit pages (as appropriate) later to replace old TOC content with the improved version that uses appropriate page titles
			$oldTOC = $pagecontent; $newTOC = $pagecontent;
			# add page formatting depending on what was entered via command line
			if ($formatting eq 'none'){
				# no formatting will use the plain TOC as index.html 
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . "index.html";
				write_file("true");
			}
			elsif ($formatting eq 'div'){
				# if using div-based formatting, we will save the TOC details to include on individual pages later
				# index.html will be a copy of the first page for each manual converted (not created until processing for that manual is complete)
				$divopen = '<div style="width:100%;"> 
Genesys Offline Documentation
<div style="float:left; width:20%;">
<!-- START OF TOC -->' . $pagecontent . '
<!-- END OF TOC -->
</div>
<div style="float:right; width:80%; ">
<!-- START OF CONTENT -->';
				$divclose = '
<!-- END OF CONTENT -->
</div>
</div>';
			}
			elsif ($formatting eq 'frames'){
				#frames will require one file to hold the TOC, and an index.html that holds the frameset structure (separating content from TOC)
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . "TOC_" . $curmanual . ".html";
				write_file("true");
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . "index.html";
				$pagecontent = '<frameset cols="250px,*">
  <frame name="toc" src="TOC_' . $curmanual. '.html">
  <frame name="content" src="' . @pagelist[0] . '.html">
</frameset>';
				write_file();
			}

			#-----------------------------------------------
			# print a heads-up of how many pages are processed
			print "      Pages processed: ";
			#-----------------------------------------------

			# process each page listed in the TOC
			foreach my $topic (@pagelist){
				$url = 'http://' . $sourceurl . '/index.php?title=Documentation:' . $product . ':' . $curmanual . ':' . $topic .  ':' . $curversion;
				if ($skin eq "none") {
					$url = $url . '&action=render';
				}
				else
				{
					$url = $url . '&useskin=' . $skin;
				}
				# get the specified topic page, set filename for writing, and prepare for processing
				if (get_url()){
					# set the filename
					$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . $topic . ".html";	
					# set topicheading to the correct H1 title and trim string
					$topicheading = $pagecontent;
					$topicheading =~ s/[\s\S]*<span class="mw-headline" id=".*">(.*)<\/span><\/h1>[\s\S]*/$1/g;
					$topicheading =~ s/^\s+|\s+$//g;
					# update new copy of TOC with the correct H1 title
					$newTOC =~ s/>$topic<\/a>/>$topicheading<\/a>/g;
#					# pre-processing may be necessary for some skins
#					if ($skin eq "&useskin=???") {
#						...
#					}
					# remove unneeded reference to port 80
					$pagecontent =~ s/docs\.genesys\.com:80/docs\.genesys\.com/g;
					# loop through version/manual arrays when fixing links
					foreach my $tempversion (@tempversion){
						foreach my $tempmanual (@tempmanual){
							# needs to build a relative path that is as shallow as possible for linking purposes!
							if ($tempversion ne $curversion){
								# go back two levels to change version
								$relativepath = "../../$tempversion/$tempmanual/";
							}
							elsif ($tempmanual ne $curmanual){
								# go back one level to change manual
								$relativepath = "../$tempmanual/";
							}
							else {
								# no change for path required
								$relativepath = '';
							}
							# remove target="_blank" calls to open offline help in separate windows
							$pagecontent =~ s/<a href="http:\/\/$sourceurl\/Documentation\/$product\/$tempversion\/$tempmanual\/(\S*)" target="_blank"/<a href="http:\/\/$sourceurl\/Documentation\/$product\/$tempversion\/$tempmanual\/$1"/g;
							# add .html to link target
							$pagecontent =~ s/href="http:\/\/$sourceurl\/Documentation\/$product\/$tempversion\/$tempmanual\/(\S*)" class=/href="$relativepath$1.html" class=/g;
							# fix any links that go directly to a section
							$pagecontent =~ s/#(\S*)\.html/\.html#$1/g;							
							#remove [edit] links if logged in
							if ($username ne ''){
								$searchstring = '<span class="editsection">\[<a href="(.*)">edit</a>\]</span>';
								$replacestring = '<!-- removed edit link -->';
								$pagecontent =~ s/$searchstring/$replacestring/g;
							}
						}
					}
					# get images from this topic and update file accordingly
					@imagelist = $mech->images;

					foreach my $tempimage (@imagelist){
						$imagename = basename($tempimage->url);
						# copy the images to a local folder
						$imageurl = "http://" . $baseurl . "/" . $tempimage->url;
						$imageurl =~ s/http:\/\/docs\.genesys\.com\/http:\/\/docs\.genesys\.com/http:\/\/docs\.genesys\.com/g;
						$status = getstore($imageurl, $basePath . '/' . $product . '/' . $curversion . '/' . $curmanual . '/images/' . $imagename);
						if (is_success($status)){
							# edit the page to point to the right location
							if ($subwiki ne "") {
								$searchstring = 'src="[http://docs\.genesys\.com]*[' . $subwiki . ']*/images/(\S*)/' . $imagename;
							}
							else {
								$searchstring = 'src="[http://docs\.genesys\.com]*/images/(\S*)/' . $imagename;
							}
							$replacestring = 'src="./images/' . $imagename;
							$pagecontent =~ s/$searchstring/$replacestring/g;
							$searchstring = 'http://' . $sourceurl . '/File:' . $imagename;
							$replacestring = './images/' . $imagename;
							$pagecontent =~ s/$searchstring/$replacestring/g;
							
						}
						else {
							print "\nerror getting image: " . $imageurl . "\n";
						}
					}
					# remove any Disqus references
					$pagecontent =~ s/<!-- avb: AvbDisqus home:(.*)Disqus<\/span><\/a>/<!-- Removed Disqus comments for offline version -->/g;
					# replace references to Tabber JavaScript and CSS
					$pagecontent =~ s/\/extensions\/Tabber\/Tabber\.js/\.\/styles\/Tabber\.js/g;
					$pagecontent =~ s/\/extensions\/Tabber\/Tabber\.css/\.\/styles\/Tabber\.css/g;
					#replace references to Multistep JavaScript and CSS
#					$pagecontent =~ s/\/extensions\/MultiStep\/scripts\/jquery-1\.10\.2\.min\.js/\.\/styles\/Multistep_a\.js/g;
#					$pagecontent =~ s/\/extensions\/MultiStep\/scripts\/jquery-migrate-1\.2\.1\.min\.js/\.\/styles\/Multistep_b\.js/g;
#					$pagecontent =~ s/\/extensions\/MultiStep\/scripts\/main\.js/\.\/styles\/Multistep_main\.js/g;
#					$pagecontent =~ s/\/extensions\/MultiStep\/css\/styles\.css/\.\/styles\/Multistep\.css/g;
					# add page formatting depending on what was entered via command line
					if ($formatting eq 'div'){
						# need to add the TOC div content to every page if using div-based formatting
						$pagecontent = $divopen . $pagecontent . $divclose;
					}
					write_file("true");
					
					#-----------------------------------------------
					# print a heads-up of what's being processed
					print "*"; 
					#-----------------------------------------------					
				}
			}
			if ($formatting eq 'div'){
				# update TOC section that is included on every page we wrote earlier
				# ...
				# create an index.html file (just a copy of the first TOC page for now)
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\index.html";
				$pagecontent = read_file($basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . @pagelist[0] . ".html", err_mode => 'carp');
				unless ($pagecontent){
					$pagecontent = "";
					print "\n  Error copying index.html: " . @pagelist[0] . ".html file doesn't exist!\n";
				}
				write_file();
			}
			elsif ($formatting eq 'none'){
				# update TOC in the index.html file
				$pagecontent = $newTOC;
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . "index.html";
				write_file("true");				
			}
			elsif ($formatting eq 'frames'){
				# update TOC
				$pagecontent = $newTOC;
				$filename = $basePath . "\\" . $product . "\\" . $curversion . "\\" . $curmanual . "\\" . "TOC_" . $curmanual . ".html";
				write_file("true");
			}
		}
	}	
}


#-----------------------------------------------
# print a confirmation that processing is done
print "\n\nProcessing complete!\nThere were $filecount HTML files created for $product.\n\n";
print "---------------------------------------------\n";
print "---------------------------------------------\n\n";
#-----------------------------------------------



#================================================
# Subroutines
#================================================

sub write_file{
	# first parameter ($_[0]) determines if file should have HTML/CSS header and footers added
	# might want to handle files differently?
	open (FILE, '>' . $filename);
	binmode(FILE, ":utf8");
	if ($_[0] eq "true") {
		print FILE $openHTML . $pagecontent . $closeHTML;
	}
	else {
		print FILE $pagecontent;
	}
	close (FILE); 
	$filecount++;
	return;
}

sub get_url{
	# used to get the currently specified URL and set the $pagecontent variable
	# some error checking provided
	my $connected = eval {
		$mech->get( $url );
		1
	};
	if (!$connected) {
		# if a connection error occurs, try again to be sure we aren't just timing out
		my $connected = eval {
			$mech->get( $url );
			1
		};		
	}
	if ($connected) {
		$pagecontent = $mech->content( base_href => $base_href );
	}
	return $connected;
}

#================================================
#================================================
