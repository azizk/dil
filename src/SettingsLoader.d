/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module SettingsLoader;

import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions;
import dil.semantic.Module,
       dil.semantic.Pass1,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.lexer.Funcs,
       dil.lexer.Identifier;
import dil.i18n.Messages,
       dil.i18n.ResourceBundle;
import dil.Diagnostics,
       dil.Compilation,
       dil.Unicode;
import util.Path;
import Settings,
       common;

import tango.sys.Environment;
import tango.io.Path : normalize;
import tango.stdc.stringz : fromStringz;

/// Loads settings from a D module file.
abstract class SettingsLoader
{
  Diagnostics diag; /// Collects error messages.
  Module mod; /// Current module.
  CompilationContext cc; /// The context.

  /// Constructs a SettingsLoader object.
  this(CompilationContext cc, Diagnostics diag)
  {
    this.cc = cc;
    this.diag = diag;
  }

  /// Creates an error report.
  /// Params:
  ///   token = Where the error occurred.
  ///   formatMsg = Error message.
  void error(Token* token, string formatMsg, ...)
  {
    auto location = token.getErrorLocation(mod.filePath);
    auto msg = Format(_arguments, _argptr, formatMsg);
    diag ~= new SemanticError(location, msg);
  }

  T getValue(T)(string name, bool isOptional = false)
  {
    auto var = mod.lookup(hashOf(name));
    if (!var && isOptional)
      return T.init;
    if (!var)
      // Returning T.init instead of null, because dmd gives an error.
      return error(mod.firstToken,
        "variable '{}' is not defined", name), T.init;
    auto t = var.node.begin;
    if (!var.isVariable)
      return error(t,
        "'{}' is not a variable declaration", name), T.init;
    auto value = var.to!(VariableSymbol).value;
    if (!value)
      return error(t,
        "'{}' variable has no value set", name), T.init;
    T val = value.Is!(T); // Try casting to T.
    if (!val)
      error(value.begin,
        "the value of '{}' must be of type {}", name, T.stringof);
    return val;
  }

  T castTo(T)(Node n)
  {
    if (auto result = n.Is!(T))
      return result;
    string type = T.stringof;
    (is(T == StringExpr) && (type = "char[]").ptr) ||
    (is(T == ArrayInitExpr) && (type = "[]").ptr) ||
    (is(T == IntExpr) && (type = "int"));
    error(n.begin, "expression is not of type {}", type);
    return null;
  }

  void load()
  {}
}

/// Loads the configuration file of dil.
class ConfigLoader : SettingsLoader
{
  /// Name of the configuration file.
  static string configFileName = "dilconf.d";
  string executablePath; /// Absolute path to dil's executable.
  string executableDir; /// Absolute path to the directory of dil's executable.
  string dataDir; /// Absolute path to dil's data directory.
  string homePath; /// Path to the home directory.

  ResourceBundle resourceBundle; /// A bundle for compiler messages.

  /// Constructs a ConfigLoader object.
  this(CompilationContext cc, Diagnostics diag, string arg0)
  {
    super(cc, diag);
    this.homePath = Environment.get("HOME");
    this.executablePath = GetExecutableFilePath(arg0);
    this.executableDir = Path(this.executablePath).path();
    Environment.set("BINDIR", this.executableDir);
  }

  static ConfigLoader opCall(CompilationContext cc, Diagnostics diag,
    string arg0)
  {
    return new ConfigLoader(cc, diag, arg0);
  }

  /// Expands environment variables such as ${HOME} in a string.
  static string expandVariables(string val)
  {
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
        result ~= String(pieceBegin, variableBegin);
        variableBegin += 2; // Skip ${
        // Get the environment variable and append it to the result.
        result ~= Environment.get(String(variableBegin, p));
        pieceBegin = p + 1; // Point to character after '}'.
      }
      p++;
    }
    if (pieceBegin < end)
      result ~= String(pieceBegin, end);
    return result;
  }

  /// Loads the configuration file.
  void load()
  {
    // Search for the configuration file.
    auto filePath = findConfigurationFilePath();
    if (filePath is null)
    {
      diag ~= new Error(new Location("",0),
        "the configuration file "~configFileName~" could not be found.");
      return;
    }
    // Load the file as a D module.
    mod = new Module(filePath, cc);
    mod.parse();

    if (mod.hasErrors)
      return;

    auto pass1 = new SemanticPass1(mod, cc);
    pass1.run();

    // Initialize the dataDir member.
    if (auto val = getValue!(StringExpr)("DATADIR"))
      this.dataDir = val.getString();
    this.dataDir = normalize(expandVariables(this.dataDir));
    GlobalSettings.dataDir = this.dataDir;
    Environment.set("DATADIR", this.dataDir);

    if (auto val = getValue!(StringExpr)("KANDILDIR"))
    {
      auto kandilDir = normalize(expandVariables(val.getString()));
      GlobalSettings.kandilDir = kandilDir;
      Environment.set("KANDILDIR", kandilDir);
    }

    if (auto array = getValue!(ArrayInitExpr)("VERSION_IDS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpr)(value))
          GlobalSettings.versionIds ~= expandVariables(val.getString());
    if (auto val = getValue!(StringExpr)("LANG_FILE"))
      GlobalSettings.langFile = normalize(expandVariables(val.getString()));
    if (auto array = getValue!(ArrayInitExpr)("IMPORT_PATHS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpr)(value))
          GlobalSettings.importPaths ~=
            normalize(expandVariables(val.getString()));
    if (auto array = getValue!(ArrayInitExpr)("DDOC_FILES"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpr)(value))
          GlobalSettings.ddocFilePaths ~=
            normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpr)("XML_MAP"))
      GlobalSettings.xmlMapFile = normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpr)("HTML_MAP"))
      GlobalSettings.htmlMapFile = normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpr)("LEXER_ERROR"))
      GlobalSettings.lexerErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpr)("PARSER_ERROR"))
      GlobalSettings.parserErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpr)("SEMANTIC_ERROR"))
      GlobalSettings.semanticErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(IntExpr)("TAB_WIDTH"))
    {
      GlobalSettings.tabWidth = cast(uint)val.number;
      Location.TAB_WIDTH = cast(uint)val.number;
    }

    auto langFile = expandVariables(GlobalSettings.langFile);
    resourceBundle = loadResource(langFile);
  }

  /// Loads a language file and returns a ResouceBundle object.
  ResourceBundle loadResource(string langFile)
  {
    // 1. Load language file.
    mod = new Module(langFile, cc);
    mod.parse();

    if (mod.hasErrors)
      return new ResourceBundle();

    auto pass1 = new SemanticPass1(mod, cc);
    pass1.run();

    // 2. Extract the values of the variables.
    string[] messages = new string[MID.max + 1];
    if (auto array = getValue!(ArrayInitExpr)("messages"))
    {
      foreach (i, value; array.values)
        if (i >= messages.length)
          break; // More messages given than allowed.
        else if (auto val = castTo!(StringExpr)(value))
          messages[i] = val.getString();
      //if (messages.length != MID.max+1)
        //error(mod.firstToken,
          //"messages table in {} must exactly have {} entries, but not {}.",
          //langFile, MID.max+1, messages.length);
    }
    string langCode;
    if (auto val = getValue!(StringExpr)("lang_code"))
      langCode = val.getString();
    string parentLangFile;
    if (auto val = getValue!(StringExpr)("inherit", true))
      parentLangFile = expandVariables(val.getString());

    // 3. Load the parent bundle if one is specified.
    auto parentRB = parentLangFile ? loadResource(parentLangFile) : null;

    // 4. Return a new bundle.
    auto rb =  new ResourceBundle(messages, parentRB);
    rb.langCode = langCode;

    return rb;
  }

  /// Searches for the configuration file of dil.
  /// Returns: the filePath or null if the file couldn't be found.
  string findConfigurationFilePath()
  {
    // 1. Look in environment variable DILCONF.
    auto filePath = Path(Environment.get("DILCONF"));
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
  /// Constructs a TagMapLoader object.
  this(CompilationContext cc, Diagnostics diag)
  {
    super(cc, diag);
  }

  static TagMapLoader opCall(CompilationContext cc, Diagnostics diag)
  {
    return new TagMapLoader(cc, diag);
  }

  string[hash_t] load(string filePath)
  {
    mod = new Module(filePath, cc);
    mod.parse();
    if (mod.hasErrors)
      return null;

    auto pass1 = new SemanticPass1(mod, cc);
    pass1.run();

    string[hash_t] map;
    if (auto array = getValue!(ArrayInitExpr)("map"))
      foreach (i, value; array.values)
      {
        auto key = array.keys[i];
        if (auto valExp = castTo!(StringExpr)(value))
          if (!key)
            error(value.begin, "expected key : value");
          else if (auto keyExp = castTo!(StringExpr)(key))
            map[hashOf(keyExp.getString())] = valExp.getString();
      }
    return map;
  }
}

/// Resolves the path to a file from the executable's dir path
/// if it is relative.
/// Returns: filePath if it is absolute or execPath + filePath.
string resolvePath(string execPath, string filePath)
{
  scope path = Path(filePath);
  if (path.isAbsolute())
    return filePath;
  path.set(execPath).append(filePath);
  return path.toString();
}

extern(Windows) uint GetModuleFileNameW(void*, wchar*, uint);
extern(C) size_t readlink(char* path, char* buf, size_t bufsize);
extern(C) char* realpath(char* base, char* dest);

/// Returns the fully qualified path to this executable,
/// or arg0 on failure or when a platform is unsupported.
/// Params:
///   arg0 = This is argv[0] from main(string[] argv).
char[] GetExecutableFilePath(char[] arg0)
{
  version(Windows)
  {
  wchar[] buffer = new wchar[256];
  uint count;

  while (1)
  {
    count = GetModuleFileNameW(null, buffer.ptr, buffer.length);
    if (count == 0)
      return arg0;
    if (buffer.length != count && buffer[count] == 0)
      break;
    // Increase size of buffer
    buffer.length = buffer.length * 2;
  }
  assert(buffer[count] == 0);
  // Reduce buffer to the actual length of the string (excluding '\0'.)
  buffer.length = count;
  return toUTF8(buffer);
  } // version(Windows)
  else version(linux)
  {
  char[] buffer = new char[256];
  size_t count;

  while (1)
  { // This won't work on very old Linux systems.
    count = readlink("/proc/self/exe".ptr, buffer.ptr, buffer.length);
    if (count == -1)
      return arg0;
    if (count < buffer.length)
      break;
    buffer.length = buffer.length * 2;
  }
  buffer.length = count;
  return buffer;
  } // version(linux)
  else version(darwin)
  {
  char[] buffer = new char[1024];  // 1024 = PATH_MAX on Mac OS X 10.5
  if (!realpath(arg0.ptr, buffer.ptr))
    return arg0;
  return fromStringz(buffer.ptr);
  } // version(darwin)
  else
  {
  pragma(msg, "Warning: GetExecutableFilePath() is not implemented on this platform.");
  return arg0;
  }
}
