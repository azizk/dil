# -*- coding: utf-8 -*-
# Author: Aziz Köksal

def append2PATH(PATH, tmp_path):
  """ Appends the given argument to the PATH in the registry. """
  import os
  from common import chunks
  from sys import platform
  is_win32 = platform is 'win32'
  path_list = PATH.split(";")

  # 1. Get the current PATH value.
  call_echo = "cmd.exe /c echo %PATH%"
  if not is_win32:
    if '/' in PATH: # Convert the Unix path to a Windows path.
      winepath = lambda p: os.popen("winepath -w " + p).read()[:-1]
      path_list = map(winepath, path_list)
      PATH = ';'.join(path_list)
    # Prepend the wine command.
    call_echo = "wine " + call_echo
  old_PATH = os.popen(call_echo).read()[:-1] # Remove \n.

  # 2. Avoid appending the same path(s) again.
  # Only compare last items.
  if old_PATH.split(';')[-len(path_list):] == path_list:
    return

  # 3. Create a temporary reg file.
  PATH = old_PATH + ";" + PATH # Join with the old PATH.
  # Encode in hex; bytes separated with a comma.
  PATH = ','.join(chunks(PATH.encode('hex'), 2))
  # Write to "tmp_path/newpath.reg".
  tmp_reg_path = os.path.join(tmp_path, "newpath.reg")
  open(tmp_reg_path, "w").write("REGEDIT4\n"
    r"[HKEY_LOCAL_MACHINE\System\CurrentControlSet"
    r"\Control\Session Manager\Environment]"
    '\nPATH = hex(2):"%s"\n' % PATH)

  # 4. Apply the reg file to the registry.
  call_regedit = "regedit.exe /S " + tmp_reg_path
  if not is_win32: # Prepend the wine command.
    call_regedit = "wine " + call_regedit
  os.system(call_regedit)
