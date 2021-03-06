#---+ Extensions
#---++ AttachContentPlugin
# **BOOLEAN**
# Enable debugging (debug messages will be written to data/debug.txt)
$Foswiki::cfg{Plugins}{AttachContentPlugin}{Debug} = 0;
# **BOOLEAN**
# By default, keep paragraph <code>&lt;p /&gt;</code> tags, <code>&lt;nop&gt;</code> tags, and square bracket type links (can be specified for each <code>ATTACHCONTENT</code> separately).
$Foswiki::cfg{Plugins}{AttachContentPlugin}{KeepPars} = 0;
# **STRING 200**
# The default comment text that will be added to saved attachments.
$Foswiki::cfg{Plugins}{AttachContentPlugin}{AttachmentComment} = 'Generated by <nop>AttachContentPlugin';

1;
