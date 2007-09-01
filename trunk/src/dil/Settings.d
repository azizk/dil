/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Settings;
import dil.Messages;
import dil.Parser, dil.SyntaxTree, dil.Declarations, dil.Expressions;
import dil.File;
import std.metastrings;

template Pad(char[] str, uint amount)
{
  static if (str.length >= amount)
    const char[] Pad = str;
  else
    const char[] Pad = "0" ~ Pad!(str, amount-1);
}

template Pad(int num, uint amount)
{
  const char[] Pad = Pad!(ToString!(num), amount);
}

version(D2)
{
  const VERSION_MAJOR = 2;
  const VERSION_MINOR = 0;
}
else
{
  const VERSION_MAJOR = 1;
  const VERSION_MINOR = 0;
}

const string VERSION = Format!("%s.%s", VERSION_MAJOR, Pad!(VERSION_MINOR, 3));
const VENDOR = "dil";

/// Used in main help message.
const COMPILED_WITH = __VENDOR__;
/// ditto
const COMPILED_VERSION = Format!("%s.%s", __VERSION__/1000, Pad!(__VERSION__%1000, 3));
/// ditto
const COMPILED_DATE = __TIMESTAMP__;

struct GlobalSettings
{
static:
  string language; /// Language of messages catalogue to load.
  string[] messages; /// Table of localized compiler messages.
  string[] importPaths; /// Array of import paths to look for modules.
  void load()
  {
    auto fileName = "config.d"[];
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
        auto val = Cast!(StringLiteralsExpression)(e);
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
            if (auto str = Cast!(StringLiteralsExpression)(value))
              GlobalSettings.importPaths ~= str.getString();
        }
        else
          throw new Exception("import_paths variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
      }
    }

    // Load messages
    sourceText = loadFile(fileName);
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
            if (auto str = Cast!(StringLiteralsExpression)(value))
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
        if (auto str = Cast!(StringLiteralsExpression)(e))
            GlobalSettings.language = str.getString();
      }
    }
    if (messages.length != MID.max+1)
      throw new Exception(std.string.format("messages table in %s must exactly have %d entries, but %s were found.", fileName, MID.max+1, messages.length));
    GlobalSettings.messages = messages;
  }
}
