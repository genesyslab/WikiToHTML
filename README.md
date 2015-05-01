# WikiToHTML

Generate flat HTML content for off-line access to documentation from work. (Response to customer request.)

## Overview

The WikiToHTML.pl script was designed to provide a quick and easy way for writers to pull content from MediaWiki into HTML format that should then be tweaked and edited to meet the needs of their project team. It should be distributed as a .rar archive that contains the following files:
- readme.html - This file, containing instructions about using the conversion script.
- WikiToHTML.pl - The perl script that generates HTML content.
- default_style.css - The default stylesheet to be used if no alternate skin is specified. (Note: support for alternate skins is a possible future improvement and not yet implemented.)

## Prerequisites

This script requires Perl with the switch module installed. 

In a Windows environment you could use the following steps:

1. Download Strawberry Perl for Windows: http://strawberryperl.com/
2. Double-click the .msi file after downloading to launch the installer.
3. Install the switch module by entering the following commands from your command prompt:

  ```
  cd C:\
  cpan
  install Switch
  exit
  ```

## Running the Script

1. Open a command prompt
2. Change the active directory to the location where your WikiToHTML.pl script and default_style.css stylesheet files are located, for example:
`cd c:\wiki\scripts`
3. Use Perl to run the script, following the Script Usage format described below. For example:
` WikiToHTML.pl -p PSDK -v 8.1.4 -m Developer`
4. Locate the WIKI_HTML folder, which is created in the directory where your script is stored (see step 2), and check that subfolders were created for the Product, Version(s) and Manual(s) you specified.
5. Browse to and open the index.html file inside any manual subfolder to review that content in your browser.

### Script Usage

`perl WikiToHTML.pl -p <product> [-v <version>] [-m <manual>] [-u <username> <password>] [-div|-noframes] [-baseurl <url>] [-subwiki <path>] [-skin <skin>]`

The available parameters are:
- `-p product`
Product to convert to HTML. Required parameter.
- `-v version`
(Optional) Version to convert to HTML. If not provided, all versions for the specified product/manual(s) will be converted to HTML. Multiple -v version parameters can be used to convert multiple versions at one time.
- `-m manual`
(Optional) Manual to convert to HTML. If not provided, all manuals for the specified product/version(s) will be converted to HTML. Multiple -m manual parameters can be used to convert multiple manuals at one time.
- `-u username password`
(Optional) Wiki login credentials. Not required if converting released content, but must be provided for unreleased content or the resulting HTML will not be accurate. There is currently no warning provided if login credentials are entered incorrectly.
- `-div`
(Optional) Uses divisions to break static HTML pages into two sections (TOC on the right and content on the left) instead of the default behavior of using frames. Differences include:
  - index.html - currently only shows TOC for -divs option, default frames also show content
  - TOC resizing options - divs cannot be manually resized
  - back button behavior - works better with frames
  - appearance - minor difference in appearance
- `-noframes`
(Optional) Generates static HTML that without the use of frames (or divisions) to provide users a TOC.
- `-baseurl url`
(Optional) Sets the base URL. If not entered, value defaults to "docs.genesys.com".
- `-subwiki path`
(Optional) Sets the subwiki path if target content isn't located in base URL folder. Default value is empty.
Sample usage: -subwiki /i18n/DEU
- `-skin skin`
(Optional) Uses a different skin for pulling HTML instead of the action=render tag. Results have not been tested.
