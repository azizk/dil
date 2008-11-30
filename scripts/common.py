# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os

def get_module_fqn(prefix_path, filepath):
  """ Returns the fully qualified module name (FQN) of a D source file.
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

def read_modules_list(path):
  from re import compile
  rx = compile(r"^(?P<path>[^,]+), (?P<fqn>\w+(?:\.\w+)*)$")
  return [match.groupdict() for match in map(rx.match, open(path)) if match]

def generate_modules_js(modlist, dest_path):
  """ Generates a JavaScript file with a list of modules FQNs. """
  if not len(modlist):
    return
  f = open(dest_path, "w")
  f.write('var modulesList = [\n  "%s"' % modlist[0]['fqn'])
  for mod in modlist[1:]:
    f.write(',\n  "%s"' % mod['fqn'])
  f.write('\n]')
  f.close()

def generate_docs(dil_exe, dest, modlist, files, versions=[], options=''):
  """ Generates documenation files. """
  files = ' '.join(files)
  versions = ' '.join(["-version=%s"%v for v in versions])
  args = dict(locals())
  os.system("%(dil_exe)s ddoc %(dest)s %(options)s %(versions)s -m=%(modlist)s %(files)s" % args)

def generate_shl_files(dil_exe, dest, prefix, files):
  """ Generates syntax highlighted files. """
  for filepath in files:
    htmlfile = get_module_fqn(prefix, filepath) + ".html"
    yield (filepath, dest/htmlfile)
    args = (dil_exe, filepath, dest/htmlfile)
    os.system('%s hl --lines --syntax --html %s > "%s"' % args)

def generate_shl_files2(dil_exe, dest, modlist):
  """ Generates syntax highlighted files. """
  for mod in modlist:
    htmlfile = mod['fqn'] + ".html"
    yield (mod['path'], dest/htmlfile)
    args = (dil_exe, mod['path'], dest/htmlfile)
    os.system('%s hl --lines --syntax --html %s > "%s"' % args)

def locate_command(command):
  """ Locates a command using the PATH environment variable. """
  from path import Path
  if 'PATH' in os.environ:
    from sys import platform
    if platform is 'win32' and Path(command).ext.lower() != ".exe":
      command += ".exe" # Append extension if we're on Windows.
    PATH = os.environ['PATH'].split(Path.pathsep)
    for path in PATH:
      path = Path(path, command)
      if path.exists:
        return path
  return None

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
    print "Downloading '%s':" % url
    js_file = urlopen(request)      # Perform the request.
    open(dest_path, "w").write(js_file.read()) # Write to destination path.
    print "Done >", dest_path
  except HTTPError, e:
    if e.code == 304: print "Not Modified"
    else:             print e
