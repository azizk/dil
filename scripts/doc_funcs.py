# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import re

def insert_svn_info(FILES, SRC_ROOT, DEST):
  """ Fetches information about Tango source files using 'svn info'
    and inserts that into the generated HTML files. """
  from subprocess import Popen, PIPE

  rx = re.compile(u"Last Changed (?:Author|Rev|Date): (.+)")

  print "Querying SVN..."

  file_paths = [f['path'] for f in FILES]
  p = Popen(["svn", "info"] + file_paths, stdout=PIPE)
  all_info = p.communicate()[0]
  # "\n\n" is the separator. The regexp makes extraction easy.
  file_infos = [rx.findall(info) for info in all_info.split("\n\n")[:-1]]

  assert(len(file_infos) == len(FILES))
  SRC_ROOT = SRC_ROOT / "" # Ensure trailing '/'.

  print "Inserting SVN information into the HTML files."

  for i, source in enumerate(FILES):
    # 1. E.g.: /svn/tango/tango/core/BitManip.d -> tango/core/BitManip.d
    src_file = source['path'].replace(SRC_ROOT, "") # Remove root dir.
    # 2. E.g.: /dest/tangodoc/ + tango.core.BitManip + .html ->
    #          /dest/tangodoc/tango.core.BitManip.html
    path = DEST/(source['fqn']+".html")
    if not path.exists:
      print "Warning: not adding SVN info to '%s'" % path
      continue
    # 3. Open the file in update mode.
    f = open(path, "r+")
    text = f.read()
    # 4. Find the insertion position.
    div = '<div id="kandil-footer">'
    insert_pos = text.rfind(div) + len(div) + 1
    text = text[insert_pos:] # Store the rest of the file.
    # 5. Insert the new content.
    f.seek(insert_pos, 0)
    fmt_args = file_infos[i] + [src_file]
    f.write("""<div class="svn_nfo"><b class="svnheader">SVN info:</b><br/>
<span class="svnlabel">Last Author:</span> <a class="svnauthor"
  href="https://www.ohloh.net/p/dtango/contributors?query={0}">{0}</a><br/>
<span class="svnlabel">Last Revision:</span> <a class="svnrevision"
  href="http://www.dsource.org/projects/tango/browser/trunk/{3}?rev={1}">
  {1}</a><br/>
<span class="svnlabel">Last Changed Date:</span>
  <span class="svndate">{2}</span></div>\n""".format(*fmt_args))
    # 6. Write the rest back and close.
    f.write(text)
    f.close()
