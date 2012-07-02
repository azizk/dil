# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals

def append2PATH(paths, tmp_path):
  """ Appends the given argument to the PATH in the registry.
      The paths argument can contain multiple paths separated by ';'. """
  from common import is_win32, Path, call_proc, call_read, subprocess, \
    chunks, tounicode, tounicodes
  paths, tmp_path = tounicodes((paths, tmp_path))
  sep = ";"
  path_list = paths.split(sep)

  # 1. Get the current PATH value.
  echo_cmd = ["wine", "cmd.exe", "/c", "echo", "%PATH%"][is_win32:]
  CUR_PATH = call_read(echo_cmd).rstrip('\r\n') # Remove trailing \r\n.
  CUR_PATH = tounicode(CUR_PATH)
  if not is_win32 and '/' in paths: # Convert the Unix paths to Windows paths.
    winepath = lambda p: call_read("winepath", "-w", p)[:-1]
    path_list = map(winepath, path_list)
    path_list = tounicodes(path_list)

  # 2. Avoid appending the same path(s) again. Strip '\' before comparing.
  op_list = [p.rstrip('\\') for p in CUR_PATH.split(sep)]
  path_list = filter((lambda p: p.rstrip('\\') not in op_list), path_list)
  if not path_list: return

  # 3. Create a temporary reg file.
  paths = sep.join(path_list)
  NEW_PATH = CUR_PATH + sep + paths + '\0' # Join with the current PATH.
  if 1 or is_win32: # Encode in hex.
    NEW_PATH = NEW_PATH.encode('utf-16')[2:].encode('hex')
    NEW_PATH = ','.join(chunks(NEW_PATH, 2)) # Comma separated byte values.
    var_type = 'hex(2)'
  #else: # Escape backslashes and wrap in quotes.
    #NEW_PATH = '"%s"' % NEW_PATH.replace('\\', '\\\\')
    #var_type = 'str(2)'
  # Write to "tmp_path/newpath.reg".
  tmp_reg = Path(tmp_path)/"newpath.reg"
  tmp_reg.write("""Windows Registry Editor Version 5.00\r
\r
[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\
Control\\Session Manager\\Environment]\r
"Path"=%s:%s\r\n""" % (var_type, NEW_PATH), encoding="utf-16")

  # 4. Apply the reg file to the registry. "/s" means run silently.
  regedit = ["wine", "regedit.exe", "/s", tmp_reg][is_win32:]
  call_proc(regedit)
