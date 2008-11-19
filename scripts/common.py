# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os

def get_module_fqn(prefix_path, filepath):
  """ Returns the fully qualified module name of a D source file.
    Note: this might not match with the module declaration
          in the source file. """
  # Remove prefix and strip off path separator.
  # E.g.: prefix_path/std/format.d -> std/format.d
  filepath = filepath[len(prefix_path):].lstrip(os.path.sep)
  # Remove the extension.
  # E.g.: std/format.d - > std/format
  filepath = os.path.splitext(filepath)[0]
  # Finally replace the path separators.
  return filepath.replace(os.path.sep, '.') # E.g.: std/format -> std.format

def download_jquery(dest_path, force=False,
                    url="http://code.jquery.com/jquery-latest.pack.js"):
  """ Downloads the jquery library from "url".
    If force is True, the file is fetched regardless
    of the "Last-Modified" header. """
  from urllib2 import Request, urlopen, HTTPError
  from time import gmtime, strftime

  request = Request(url)

  if dest_path.exists and not force: # Create a GMT date stamp.
    date_stamp = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(dest_path.mtime))
    request.add_header('If-Modified-Since', date_stamp)

  try:
    print "Downloading '%s':" % url,
    js_file = urlopen(request)                 # Perform the request.
    open(dest_path, "w").write(js_file.read()) # Write to destination path.
    print "Done"
  except HTTPError, e:
    if e.code == 304: print "Not Modified"
    else:             print e
