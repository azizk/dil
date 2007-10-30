/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Settings;
import dil.Messages;
import dil.Parser, dil.SyntaxTree, dil.Declarations, dil.Expressions;
import dil.File;
import tango.io.FilePath;
import common;

struct GlobalSettings
{
static:
  string language; /// Language of loaded messages catalogue.
  string[] messages; /// Table of localized compiler messages.
  string[] importPaths; /// Array of import paths to look for modules.
  void load()
  {
    scope execPath = new FilePath(GetExecutableFilePath());
    auto fileName = execPath.file("config.d").toUtf8();
    auto sourceText = loadFile(fileName);
    auto parser = new Parser(sourceText, fileName);
    auto root = parser.start();

    if (parser.errors.length || parser.lx.errors.length)
    {
      throw new Exception("There are errors in " ~ fileName ~ ".");
    }

    foreach (decl; root.children)
    {
      auto v = Cast!(VariableDeclaration)(decl);
      if (v is null)
        continue;
      auto vname = v.idents[0].srcText;
      if (vname == "langfile")
      {
        auto e = v.values[0];
        if (!e)
          throw new Exception("langfile variable has no value set.");
        auto val = Cast!(StringExpression)(e);
        if (val)
          // Set fileName to d-file with messages table.
          fileName = val.getString();
      }
      else if (vname == "import_paths")
      {
        auto e = v.values[0];
        if (e is null)
          throw new Exception("import_paths variable has no variable set.");
        if (auto array = Cast!(ArrayInitializer)(e))
        {
          foreach (value; array.values)
            if (auto str = Cast!(StringExpression)(value))
              GlobalSettings.importPaths ~= str.getString();
        }
        else
          throw new Exception("import_paths variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
      }
    }

    // Load messages
    sourceText = loadFile(execPath.file(fileName).toUtf8());
    parser = new Parser(sourceText, fileName);
    root = parser.start();

    if (parser.errors.length || parser.lx.errors.length)
    {
      throw new Exception("There are errors in "~fileName~".");
    }

    char[][] messages;
    foreach (decl; root.children)
    {
      auto v = Cast!(VariableDeclaration)(decl);
      if (v is null)
        continue;
      if (v.idents[0].srcText == "messages")
      {
        auto e = v.values[0];
        if (!e)
          throw new Exception("messages variable in "~fileName~" has no value set.");
        if (auto array = Cast!(ArrayInitializer)(e))
        {
          foreach (value; array.values)
          {
            if (auto str = Cast!(StringExpression)(value))
              messages ~= str.getString();
          }
        }
        else
          throw new Exception("messages variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
      }
      else if(v.idents[0].srcText == "lang_code")
      {
        auto e = v.values[0];
        if (!e)
          throw new Exception("lang_code variable in "~fileName~" has no value set.");
        if (auto str = Cast!(StringExpression)(e))
            GlobalSettings.language = str.getString();
      }
    }
    if (messages.length != MID.max+1)
      throw new Exception(Format("messages table in {0} must exactly have {1} entries, but {2} were found.", fileName, MID.max+1, messages.length));
    GlobalSettings.messages = messages;
    dil.Messages.SetMessages(messages);
  }
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
  static assert(0, "GetExecutableFilePath() is not implemented on your platform.");
