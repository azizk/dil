module docgen.config.reader;

debug import tango.io.Stdout;

char[][] lex(char[] input) {
  char[][] tokens;

  uint state = 0, level = 0;
  size_t sidx = 0;

  void err(size_t i, int type = 0) {
    auto b = input[i<20 ? 0 : i-20..i];
    auto e = input[i+1..i+21>$ ? $ : i+21];

    throw new Exception("Lex: " ~ 
      (type == 0 ? "Illegal character" :
      type == 1 ? "Wrong number of parenthesis" :
      "Unexpected end of input") ~
      ": " ~ b ~ "  >>>" ~ input[i] ~ "<<<  " ~ e ~ "."
    );
  }
  void begin(size_t i) { sidx = i; }
  void end(size_t i) { tokens ~= input[sidx..i]; }

  foreach(size_t i, c; input) {
    if (sidx > i) continue;
    switch(c) { // states space, token, textEnd
      case '"':
        switch(state) {
          case 0:
            char[] buf;
            bool escape;
            char d;
            sidx = i;
            while(!((d = input[++sidx]) == '"' && !escape) && sidx<input.length)
              if (escape) {
                if (d != '"' && d != '\\') buf ~= '\\';
                buf ~= d;
                escape = false;
              } else if (d == '\\')
                escape = true;
              else
                buf ~= d;

            sidx++;
            tokens ~= buf;
            state = 2;
            continue;
          default: err(i);
        }
      case '\\':
        switch(state) {
          case 0: begin(i); state = 1; continue;
          case 1: continue;
          case 2: err(i);
        }
      case ' ':
      case '\t':
      case '\n':
      case '(':
      case ')':
        switch(state) {
          case 1: end(i);
          case 0:
          case 2:
            switch(c) {
              case '(': tokens ~= "("; level++; state = 0; break;
              case ')': tokens ~= ")"; if (!level--) err(i,1);
              default: state = 0;
            }
        }
        break;
      default:
        switch(state) {
          case 0: begin(i);
          case 1: state = 1; continue;
          case 2: err(i);
        }
     }
  }

  if (state == 3 || level != 0) err(input.length-1,2);
  if (state > 0) end(input.length);

  debug {
    foreach(i, tok; tokens)
      Stdout.format("{}{}", tok, (i != tokens.length-1 ? " " : ""));
    Stdout.newline;
  }

  return tokens;
}

char[][][char[]] parse(char[][] tokens) {
  char[][][char[]] values;
  size_t i = 1;

  void err(size_t j) {
    auto b = tokens[j < 5 ? 0 : j-5..j];
    auto e = tokens[j+1..j+6>$ ? $ : j+6];
    char[] tmp;
    foreach(t; b) tmp ~= t ~ " ";
    tmp ~= ">>>" ~ tokens[j] ~ "<<< ";
    foreach(t; e) tmp ~= t ~ " ";

    throw new Exception(
      "Parse: Illegal token: " ~ tmp ~ "."
    );
  }

  if (tokens[0] != "(") err(0);

  void doParse(char[] prefix = null) {
    if (tokens[i] == "(" ||
        tokens[i] == ")") err(i);
    if (prefix) prefix ~= ".";
    auto v = prefix ~ tokens[i++];
    //values[v] = null;
    while (tokens[i] != ")")
      if (tokens[i++] == "(")
        doParse(v);
      else
        values[v] ~= tokens[i-1];
    i++;
  }

  doParse();

  return values;
}
