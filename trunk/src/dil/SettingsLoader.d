/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.SettingsLoader;

import dil.Settings;
import dil.Messages;
import dil.ast.Node, dil.ast.Declarations, dil.ast.Expressions;
import dil.semantic.Module;
import dil.File;
import tango.io.FilePath;
import common;

void loadSettings()
{
  scope execPath = new FilePath(GetExecutableFilePath());
  execPath = new FilePath(execPath.folder());

  // Load config.d
  auto filePath = resolvePath(execPath, "config.d");
  auto modul = new Module(filePath);
  modul.parse();

  if (modul.hasErrors)
    throw new Exception("There are errors in " ~ filePath ~ ".");

  foreach (decl; modul.root.children)
  {
    auto v = decl.Is!(VariablesDeclaration);
    if (v is null)
      continue;

    auto variableName = v.names[0].str;
    auto e = v.inits[0];
    if (!e)
      throw new Exception(variableName ~ " variable has no value set.");

    switch (variableName)
    {
    case "langfile":
      if (auto val = e.Is!(StringExpression))
        GlobalSettings.langFile = val.getString();
      break;
    case "import_paths":
      if (auto array = e.Is!(ArrayInitExpression))
      {
        foreach (value; array.values)
          if (auto str = value.Is!(StringExpression))
            GlobalSettings.importPaths ~= str.getString();
      }
      else
        throw new Exception("import_paths variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
      break;
    case "ddoc_files":
      if (auto array = e.Is!(ArrayInitExpression))
      {
        foreach (value; array.values)
          if (auto str = value.Is!(StringExpression))
            GlobalSettings.ddocFilePaths ~= str.getString();
      }
      else
        throw new Exception("import_paths variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
      break;
    case "lexer_error":
      if (auto val = e.Is!(StringExpression))
        GlobalSettings.lexerErrorFormat = val.getString();
      break;
    case "parser_error":
      if (auto val = e.Is!(StringExpression))
        GlobalSettings.parserErrorFormat = val.getString();
      break;
    case "semantic_error":
      if (auto val = e.Is!(StringExpression))
        GlobalSettings.semanticErrorFormat = val.getString();
      break;
    default:
    }
  }

  // Load language file.
  filePath = resolvePath(execPath, GlobalSettings.langFile);
  modul = new Module(filePath);
  modul.parse();

  if (modul.hasErrors)
    throw new Exception("There are errors in "~filePath~".");

  char[][] messages;
  foreach (decl; modul.root.children)
  {
    auto v = decl.Is!(VariablesDeclaration);
    if (v is null)
      continue;

    auto variableName = v.names[0].str;
    auto e = v.inits[0];
    if (!e)
      throw new Exception(variableName~" variable in "~filePath~" has no value set.");

    switch (variableName)
    {
    case "messages":
      if (auto array = e.Is!(ArrayInitExpression))
      {
        foreach (value; array.values)
        {
          if (auto str = value.Is!(StringExpression))
            messages ~= str.getString();
        }
      }
      else
        throw new Exception("messages variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
      break;
    case "lang_code":
      if (auto str = e.Is!(StringExpression))
          GlobalSettings.langCode = str.getString();
      break;
    default:
    }
  }
  if (messages.length != MID.max+1)
    throw new Exception(
      Format(
        "messages table in {0} must exactly have {1} entries, but {2} were found.",
        filePath, MID.max+1, messages.length)
      );
  GlobalSettings.messages = messages;
  dil.Messages.SetMessages(messages);
}

string resolvePath(FilePath execPath, string filePath)
{
  if ((new FilePath(filePath)).isAbsolute())
    return filePath;
  return execPath.dup.append(filePath).toString();
}

version(Windows)
{
private extern(Windows) uint GetModuleFileNameA(void*, char*, uint);
/++
  Get the fully qualified path to this executable.
+/
char[] GetExecutableFilePath()
{
  alias GetModuleFileNameA GetModuleFileName;
  char[] buffer = new char[256];
  uint count;

  while (1)
  {
    if (buffer is null)
      return null;

    count = GetModuleFileName(null, buffer.ptr, buffer.length);
    if (count == 0)
      return null;
    if (buffer.length != count && buffer[count] == 0)
      break;
    // Increase size of buffer
    buffer.length = buffer.length * 2;
  }
  assert(buffer[count] == 0);
  // Reduce buffer to the actual length of the string (excluding '\0'.)
  if (count < buffer.length)
    buffer.length = count;
  return buffer;
}
}
else version(linux)
{
private extern(C) size_t readlink(char* path, char* buf, size_t bufsize);
/++
  Get the fully qualified path to this executable.
+/
char[] GetExecutableFilePath()
{
  char[] buffer = new char[256];
  size_t count;

  while (1)
  {
    // This won't work on very old Linux systems.
    count = readlink("/proc/self/exe".ptr, buffer.ptr, buffer.length);
    if (count == -1)
      return null;
    if (count < buffer.length)
      break;
    buffer.length = buffer.length * 2;
  }
  buffer.length = count;
  return buffer;
}
}
else
  static assert(0, "GetExecutableFilePath() is not implemented on this platform.");
