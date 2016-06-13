# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2015,2016 Foswiki Contributors
# Copyright (c) 2007,2009 Arthur Clemens
# Copyright (c) 2006 Meredith Lesly, Kenneth Lavrsen
# and TWiki Contributors. All Rights Reserved.
# Contributors are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.

package Foswiki::Plugins::AttachContentPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;
use Foswiki::Func ();
use File::Temp();
use Digest::MD5 qw(md5_hex);
use Encode qw();

our $VERSION = '2.41';
our $RELEASE = '13 Jun 2016';
our $SHORTDESCRIPTION  = 'Saves dynamic topic text to an attachment';
our $NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
my $pluginName = 'AttachContentPlugin';
my $savedAlready;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    _initVariables();

    Foswiki::Func::registerTagHandler( 'STARTATTACH', \&_startAttach );
    Foswiki::Func::registerTagHandler( 'ENDATTACH',   \&_endAttach );

    return 1;
}

sub _startAttach { }
sub _endAttach   { }

=pod

=cut

sub _initVariables {
    $savedAlready = 0;
}

=pod

=cut

sub beforeCommonTagsHandler {

    #my ($text, $topic, $web, $meta ) = @_;

    $_[0] =~
s/%STARTATTACH\{(.*?)\}%(.*?)%ENDATTACH%/&_handleAttachBeforeRendering($1, $2, $_[2], $_[1])/ges;
}

=pod

_handleAttachBeforeRendering($attributes, $content, $web, $topic)

Removes content if param hidecontent is true.

=cut

sub _handleAttachBeforeRendering {
    my ( $inAttr, $inContent, $inWeb, $inTopic ) = @_;

    my $attrs =
      Foswiki::Func::expandCommonVariables( $inAttr, $inTopic, $inWeb );
    my %params = Foswiki::Func::extractParameters($attrs);
    return '' if Foswiki::Func::isTrue( $params{'hidecontent'} );
    $inContent =~ s/^\s+|\s+$//g;
    return $inContent;
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )

=cut

sub afterSaveHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    _debug("afterSaveHandler");

    my $query = Foswiki::Func::getCgiQuery();

    # Do not run plugin when managing attachments.
    # SMELL: does afterSaveHandler get called in this situation?
    return if Foswiki::Func::getContext()->{'upload'};

    return if $savedAlready;
    $savedAlready = 1;

    _debug("sub afterSaveHandler( $_[2].$_[1] )");

    $_[0] =~
s/%STARTATTACH\{(.*?)\}%(.*?)%ENDATTACH%/&_handleAttach($1, $2, $_[2], $_[1])/ges;
    $savedAlready = 0;

    return;
}

=pod

_handleAttach($attributes, $content, $web, $topic)

=cut

sub _handleAttach {
    my ( $inAttr, $inContent, $inWeb, $inTopic ) = @_;

    _debug("sub handleAttach; attr=$inAttr; content=$inContent");

    my $attrs =
      Foswiki::Func::expandCommonVariables( $inAttr, $inTopic, $inWeb );
    my %params = Foswiki::Func::extractParameters($attrs);

    my $attrFileName = $params{_DEFAULT};
    return '' unless $attrFileName;

    my $web   = $params{'web'}   || $inWeb;
    my $topic = $params{'topic'} || $inTopic;
    ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

    my $user = Foswiki::Func::getWikiName();
    unless (Foswiki::Func::checkAccessPermission("CHANGE", $user, undef, $topic, $web)) {
      _debug("user $user doesn't have change access on $web.$topic");
      return '';
    }

    my $comment = $params{'comment'}
      || $Foswiki::cfg{Plugins}{AttachContentPlugin}{AttachmentComment};
    my $hide = Foswiki::Func::isTrue( $params{'hide'} );
    my $keepPars =
      Foswiki::Func::isTrue( $params{'keeppars'}, $Foswiki::cfg{Plugins}{AttachContentPlugin}{KeepPars} );

    my $workArea = Foswiki::Func::getWorkArea($pluginName);

    ($web)      ? _debug("\t web: $web")           : _debug("\t no web");
    ($topic)    ? _debug("\t topic: $topic")       : _debug("\t no topic");
    ($comment)  ? _debug("\t comment: $comment")   : _debug("\t no comment");
    ($hide)     ? _debug("\t hide: $hide")         : _debug("\t no hide");
    ($keepPars) ? _debug("\t keepPars: $keepPars") : _debug("\t no keepPars");
    ($workArea) ? _debug("\t workArea: $workArea") : _debug("\t no workArea");

    # Protect against evil filenames - especially for out temp file.
    my ( $fileName, $orgName ) =
      Foswiki::Func::sanitizeAttachmentName($attrFileName);
    _debug("\t fileName=$fileName");

    # Turn most TML to text
    my $content =
      Foswiki::Func::expandCommonVariables( $inContent, $topic, $web );

    # Turn paragraphs, nops, and bracket links into plain text
    unless ($keepPars) {
        $content =~ s/<p\s*\/>/\n/go;
        $content =~ s/<nop>//goi;
        $content =~ s/\[\[.+?\]\[(.+?)\]\]/$1/go;
        $content =~ s/\[\[(.+?)\]\]/$1/go;
    }

    # strip spaces from content
    $content =~ s/^[[:space:]]+//s;    # trim at start
    $content =~ s/[[:space:]]+$//s;    # trim at end
    ($content) ? _debug("\t content: $content") : _debug("\t no content");

    my $newMD5 = md5_hex(_encode($content));
    my $oldContent = Foswiki::Func::readAttachment($web, $topic, $fileName) || '';
    my $oldMD5 = md5_hex($oldContent);

    if ($newMD5 ne $oldMD5) {

      my $fh = File::Temp->new();
      my $tempName = $fh->filename;
      _debug("\t tempName: $tempName");

      # Saving temporary file
      Foswiki::Func::saveFile( $tempName, $content, 1 );

      my @stats    = stat $tempName;
      my $fileSize = $stats[7];
      my $fileDate = $stats[9];

      Foswiki::Func::saveAttachment(
          $web, $topic,
          $fileName,
          {
              file     => $tempName,
              filedate => $fileDate,
              filesize => $fileSize,
              filepath => $fileName,
              comment  => $comment,
              hide     => $hide
          }
      );
    }

    return '';
}

=pod

writes a debug message if the $debug flag is set

=cut

sub _debug {
    my ($text) = @_;

    Foswiki::Func::writeDebug("$pluginName; $text")
      if $Foswiki::cfg{Plugins}{AttachContentPlugin}{Debug};
}

sub _encode {
    my ($text) = @_;

    return Encode::encode($Foswiki::cfg{Site}{CharSet} || 'utf-8', $text);
}

1;
