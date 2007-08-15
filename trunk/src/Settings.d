/++
  Author: Aziz Köksal
  License: GPL3
+/
module Settings;
import Parser, SyntaxTree, Declarations, Expressions;
import std.metastrings;

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
const string VERSION = Format!("%s.%s", VERSION_MAJOR, VERSION_MINOR);

const COMPILED_WITH = __VENDOR__;
const COMPILED_VERSION = Format!("%s.%s", __VERSION__/1000, __VERSION__%1000);
const COMPILED_DATE = __TIMESTAMP__;

const usageHighlight = "highlight (hl) file.d";

struct GlobalSettings
{
static:
  string language; /// Language of messages catalogue to load.
  string[] messages; /// Table of localized compiler messages.
  void load()
  {
    auto fileName = "config.d"[];
    auto sourceText = cast(char[]) std.file.read(fileName);
    auto parser = new Parser(sourceText, fileName);
    parser.start();
    auto root = parser.parseModule();

    if (parser.errors.length || parser.lx.errors.length)
    {
      throw new Exception("There are errors in " ~ fileName ~ ".");
    }

    foreach (decl; root.children)
    {
      auto v = Cast!(VariableDeclaration)(decl);
      if (v && v.idents[0].srcText == "language")
      {
        auto e = v.values[0];
        if (!e)
          throw new Exception("language variable has no value set.");
        auto val = Cast!(StringLiteralsExpression)(e);
        if (val)
        {
          GlobalSettings.language = val.getString();
          break;
        }
      }
    }

    // Load messages
    if (GlobalSettings.language.length)
    {
      fileName = "lang_" ~ GlobalSettings.language ~ ".d";
      sourceText = cast(char[]) std.file.read(fileName);
      parser = new Parser(sourceText, fileName);
      parser.start();
      root = parser.parseModule();

      if (parser.errors.length || parser.lx.errors.length)
      {
        throw new Exception("There are errors in "~fileName~".");
      }

      char[][] messages;
      foreach (decl; root.children)
      {
        auto v = Cast!(VariableDeclaration)(decl);
        if (v && v.idents[0].srcText == "messages")
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
      }
      GlobalSettings.messages = messages;
    }
  }

}
