/++
  Author: Aziz Köksal
  License: GPL3
+/
module SettingsLoader;

import Settings;
import dil.Messages;
import dil.ast.Node, dil.ast.Declarations, dil.ast.Expressions;
import dil.semantic.Module;
import dil.semantic.Pass1;
import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.Information;
import dil.Compilation;
import common;

import tango.io.FilePath;
import tango.sys.Environment;

/// Loads settings from a D module file.
abstract class SettingsLoader
{
  InfoManager infoMan; /// Collects error messages.
  Module mod; /// Current module.

  this(InfoManager infoMan)
  {
    this.infoMan = infoMan;
  }

  /// Creates an error report.
  /// Params:
  ///   token = where the error occurred.
  ///   formatMsg = error message.
  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    infoMan ~= new SemanticError(location, msg);
  }

  T getValue(T)(char[] name)
  {
    auto var = mod.lookup(name);
    if (!var) // Returning T.init instead of null, because dmd gives an error.
      return error(mod.firstToken, "variable '{}' is not defined", name), T.init;
    auto t = var.node.begin;
    if (!var.isVariable)
      return error(t, "'{}' is not a variable declaration", name), T.init;
    auto value = var.to!(Variable).value;
    if (!value)
      return error(t, "'{}' variable has no value set", name), T.init;
    T val = value.Is!(T); // Try casting to T.
    if (!val)
      error(value.begin, "the value of '{}' must be of type {}", name, T.stringof);
    return val;
  }

  T castTo(T)(Node n)
  {
    if (auto result = n.Is!(T))
      return result;
    char[] type = T.stringof;
    (is(T == StringExpression) && (type = "char[]").ptr) ||
    (is(T == ArrayInitExpression) && (type = "[]").ptr) ||
    (is(T == IntExpression) && (type = "int"));
    error(n.begin, "expression is not of type {}", type);
    return null;
  }

  void load()
  {}
}

/// Loads the configuration file of dil.
class ConfigLoader : SettingsLoader
{
  static string configFileName = "dilconf.d"; /// Name of the configuration file.
  string executablePath; /// Absolute path to dil's executable.
  string executableDir; /// Absolute path to the directory of dil's executable.
  string dataDir; /// Absolute path to dil's data directory.
  string homePath; /// Path to the home directory.

  this(InfoManager infoMan)
  {
    super(infoMan);
    this.homePath = Environment.get("HOME");
    this.executablePath = GetExecutableFilePath();
    this.executableDir = (new FilePath(this.executablePath)).folder();
    Environment.set("BINDIR", this.executableDir);
  }

  static ConfigLoader opCall(InfoManager infoMan)
  {
    return new ConfigLoader(infoMan);
  }

  static string expandVariables(string val)
  {
    char[] makeString(char* begin, char* end)
    {
      assert(begin && end && begin <= end);
      return begin[0 .. end - begin];
    }

    char[] result;
    char* p = val.ptr, end = p + val.length;
    char* pieceBegin = p; // Points to the piece of the string after a variable.

    while (p+3 < end)
    {
      if (p[0] == '$' && p[1] == '{')
      {
        auto variableBegin = p;
        while (p < end && *p != '}')
          p++;
        if (p == end)
          break; // Don't expand unterminated variables.
        result ~= makeString(pieceBegin, variableBegin);
        variableBegin += 2; // Skip ${
        // Get the environment variable and append it to the result.
        result ~= Environment.get(makeString(variableBegin, p));
        pieceBegin = p + 1; // Point to character after '}'.
      }
      p++;
    }
    if (pieceBegin < end)
      result ~= makeString(pieceBegin, end);
    return result;
  }

  void load()
  {
    // Search for the configuration file.
    auto filePath = findConfigurationFilePath();
    if (filePath is null)
    {
      infoMan ~= new Error(new Location("",0),
        "the configuration file "~configFileName~" could not be found.");
      return;
    }
    // Load the file as a D module.
    mod = new Module(filePath, infoMan);
    mod.parse();

    if (mod.hasErrors)
      return;

    auto context = new CompilationContext;
    auto pass1 = new SemanticPass1(mod, context);
    pass1.run();

    // Initialize the dataDir member.
    if (auto val = getValue!(StringExpression)("DATADIR"))
      this.dataDir = val.getString();
    this.dataDir = expandVariables(this.dataDir);
    GlobalSettings.dataDir = this.dataDir;
    Environment.set("DATADIR", this.dataDir);

    if (auto array = getValue!(ArrayInitExpression)("VERSION_IDS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          GlobalSettings.versionIds ~= expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("LANG_FILE"))
      GlobalSettings.langFile = expandVariables(val.getString());
    if (auto array = getValue!(ArrayInitExpression)("IMPORT_PATHS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          GlobalSettings.importPaths ~= expandVariables(val.getString());
    if (auto array = getValue!(ArrayInitExpression)("DDOC_FILES"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          GlobalSettings.ddocFilePaths ~= expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("XML_MAP"))
      GlobalSettings.xmlMapFile = expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("HTML_MAP"))
      GlobalSettings.htmlMapFile = expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("LEXER_ERROR"))
      GlobalSettings.lexerErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("PARSER_ERROR"))
      GlobalSettings.parserErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("SEMANTIC_ERROR"))
      GlobalSettings.semanticErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(IntExpression)("TAB_WIDTH"))
    {
      GlobalSettings.tabWidth = val.number;
      Location.TAB_WIDTH = val.number;
    }


    // Load language file.
    // TODO: create a separate class for this?
    filePath = expandVariables(GlobalSettings.langFile);
    mod = new Module(filePath);
    mod.parse();

    if (mod.hasErrors)
      return;

    pass1 = new SemanticPass1(mod, context);
    pass1.run();

    if (auto array = getValue!(ArrayInitExpression)("messages"))
    {
      char[][] messages;
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          messages ~= val.getString();
      if (messages.length != MID.max+1)
        error(mod.firstToken,
              "messages table in {} must exactly have {} entries, but not {}.",
              filePath, MID.max+1, messages.length);
      GlobalSettings.messages = messages;
      dil.Messages.SetMessages(messages);
    }
    if (auto val = getValue!(StringExpression)("lang_code"))
      GlobalSettings.langCode = val.getString();
  }

  /// Searches for the configuration file of dil.
  /// Returns: the filePath or null if the file couldn't be found.
  string findConfigurationFilePath()
  {
    // 1. Look in environment variable DILCONF.
    auto filePath = new FilePath(Environment.get("DILCONF"));
    if (filePath.exists())
      return filePath.toString();
    // 2. Look in the current working directory.
    filePath.set(this.configFileName);
    if (filePath.exists())
      return filePath.toString();
    // 3. Look in the directory set by HOME.
    filePath.set(this.homePath);
    filePath.append(this.configFileName);
    if (filePath.exists())
      return filePath.toString();
    // 4. Look in the binary's directory.
    filePath.set(this.executableDir);
    filePath.append(this.configFileName);
    if (filePath.exists())
      return filePath.toString();
    return null;
  }
}

/// Loads an associative array from a D module file.
class TagMapLoader : SettingsLoader
{
  this(InfoManager infoMan)
  {
    super(infoMan);
  }

  static TagMapLoader opCall(InfoManager infoMan)
  {
    return new TagMapLoader(infoMan);
  }

  string[string] load(string filePath)
  {
    mod = new Module(filePath, infoMan);
    mod.parse();
    if (mod.hasErrors)
      return null;

    auto context = new CompilationContext;
    auto pass1 = new SemanticPass1(mod, context);
    pass1.run();

    string[string] map;
    if (auto array = getValue!(ArrayInitExpression)("map"))
      foreach (i, value; array.values)
      {
        auto key = array.keys[i];
        if (auto valExp = castTo!(StringExpression)(value))
          if (!key)
            error(value.begin, "expected key : value");
          else if (auto keyExp = castTo!(StringExpression)(key))
            map[keyExp.getString()] = valExp.getString();
      }
    return map;
  }
}

/// Resolves the path to a file from the executable's dir path
/// if it is relative.
/// Returns: filePath if it is absolute or execPath + filePath.
string resolvePath(string execPath, string filePath)
{
  scope path = new FilePath(filePath);
  if (path.isAbsolute())
    return filePath;
  path.set(execPath).append(filePath);
  return path.toString();
}

version(DDoc)
{
  /// Returns the fully qualified path to this executable.
  char[] GetExecutableFilePath();
}
else version(Windows)
{
private extern(Windows) uint GetModuleFileNameA(void*, char*, uint);

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
