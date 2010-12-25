# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
import re

def insert_svn_info(FILES, SRC_ROOT, DEST,
  rev_link, author_link, template=None):
  """ Fetches information about Tango source files using 'svn info'
    and inserts that into the generated HTML files. """
  from subprocess import Popen, PIPE

  rx = re.compile("Last Changed (?:Author|Rev|Date): (.+)")

  if template == None: # Use default:
    # {0}=Author; {1}=Revision; {2}=Date
    template = """<div class="svn_nfo"><h3 class="svnheader">SVN info:</h3>
<span class="svnlabel">Last Author:</span> <a class="svnauthor"
  href="{author_link}">{0}</a><br/>
<span class="svnlabel">Last Revision:</span> <a class="svnrevision"
  href="{rev_link}">{1}</a><br/>
<span class="svnlabel">Last Changed Date:</span>
  <span class="svndate">{2}</span></div>\n"""

  print("Querying SVN...")

  file_paths = [f['path'] for f in FILES]
  p = Popen(["svn", "info"] + file_paths, stdout=PIPE)
  all_info = p.communicate()[0]
  # "\n\n" is the separator. The regexp makes extraction easy.
  file_infos = [rx.findall(info) for info in all_info.split("\n\n")[:-1]]

  assert(len(file_infos) == len(FILES))
  SRC_ROOT = SRC_ROOT / "" # Ensure trailing '/'.

  print("Inserting SVN information into the HTML files.")

  for i, source in enumerate(FILES):
    # 1. E.g.: /svn/tango/tango/core/BitManip.d -> tango/core/BitManip.d
    src_file = source['path'].replace(SRC_ROOT, "") # Remove root dir.
    # 2. E.g.: /dest/tangodoc/ + tango.core.BitManip + .html ->
    #          /dest/tangodoc/tango.core.BitManip.html
    path = DEST/(source['fqn']+".html")
    if not path.exists:
      print("Warning: file inexistent: '%s'. Not adding SVN info to it." % path)
      continue
    # 3. Open the file in update mode.
    # No encoding is used to make seeking and inserting uncomplicated.
    f = path.open("r+", encoding=None)
    text = f.read()
    # 4. Find the insertion position.
    div = '<div id="kandil-footer">'.encode("u8")
    insert_pos = text.rfind(div) + len(div) + 1
    text = text[insert_pos:] # Store the rest of the file.
    # 5. Insert the new content.
    f.seek(insert_pos, 0)
    fmt_args = file_infos[i]
    f.write(template.format(*fmt_args,
      author_link=author_link.format(fmt_args[0]),
      rev_link=rev_link.format(src_file, fmt_args[1])).encode("u8"))
    # 6. Write the rest back and close.
    f.write(text)
    f.close()
