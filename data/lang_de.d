/++
  Author: Aziz Köksal
  License: GPL3
+/

string lang_code = "de";

string[] messages = [
  // Lexer messages:
  "illegales Zeichen gefunden: '{0}'",
//   "ungültiges Unicodezeichen.",
  "ungültige UTF-8-Sequenz: '{0}'",
  // ''
  "ungeschlossenes Zeichenliteral",
  "leeres Zeichenliteral.",
  // #line
  "erwartete 'line' nach '#'.",
  "Ganzzahl nach #line erwartet.",
//   `erwartete Dateispezifikation (z.B. "pfad\zur\datei".)`,
  "ungeschlossene Dateispezifikation (filespec)",
  "ein Special Token muss mit einem Zeilenumbruch abgeschlossen werden.",
  // ""
  "ungeschlossene Zeichenkette",
  // x""
  "Nicht-Hexzeichen '{0}' in Hexzeichenkette gefunden.",
  "ungerade Anzahl von Hexziffern in Hexzeichenkette.",
  "ungeschlossene Hexzeichenkette",
  // /* */ /+ +/
  "ungeschlossener Blockkommentar (/* */)",
  "ungeschlossener verschachtelter Kommentar (/+ +/)",
  // `` r""
  "ungeschlossene rohe Zeichenkette.",
  "ungeschlossene Backquote-Zeichenkette.",
  // \x \u \U
  "undefinierte Escapesequenz '{0}' gefunden.",
  "ungültige Unicode-Escapesequenz '{0}' gefunden.",
  "unzureichende Anzahl von Hexziffern in Escapesequenz: '{0}'",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "undefinierte HTML-Entität ‚{0}‘",
  "ungeschlossene HTML-Entität ‚{0}‘",
  "HTML-Entitäten müssen mit einem Buchstaben beginnen.",
  // integer overflows
  "Dezimalzahl überläuft im Vorzeichenbit.",
  "Überlauf in Dezimalzahl.",
  "Überlauf in Hexadezimalzahl.",
  "Überlauf in Binärzahl.",
  "Überlauf in Oktalzahl.",
  "Überlauf in Fließkommazahl.",
  "die Ziffern 8 und 9 sind in Oktalzahlen unzulässig.",
  "ungültige Hexzahl; mindestens eine Hexziffer erforderlich.",
  "ungültige Binärzahl; mindestens eine Binärziffer erforderlich.",
  "der Exponent einer hexadezimalen Fließkommazahl ist erforderlich.",
  "Hexadezimal-Exponenten müssen mit einer Dezimalziffer anfangen.",
  "Exponenten müssen mit einer Dezimalziffer anfangen.",
  "die Moduldatei konnte nicht gelesen werden",
  "die Moduldatei existiert nicht",
  "die Oktalzahl ist größer als 0xFF: ‘{}’",
  "der Dateiname ‘{}’ kann nicht als Modulname benutzt werden; es ist ein ungültiger oder reservierter D-Bezeichner",
  "das Trennzeichen darf kein Leerzeichen sein",
  "erwartete ein Trennzeichen oder einen Bezeichner nach ‘q\"’",
  "erwartete eine neue Zeile nach dem Trennbezeichner ‘{}’",
  "ungeschlossene abgegrenzte Zeichenkette",
  "erwartete ‘\"’ nach dem Trenner ‘{}’",
  "ungeschlossene Tokenzeichenkette",

  // Parser messages:
  "erwartete ‚{0}‘, fand aber ‚{1}‘",
  "‚{0}‘ ist redundant",
  "Template-Tupel-Parameter dürfen nur am Ende auftreten",
  "der ‚in’-Vertrag der Funktion wurde bereits geparst",
  "der ‚out’-Vertrag der Funktion wurde bereits geparst",
  "es wurde kein Anbindungstyp angegeben",
  "unbekannter Anbindungstyp ‚{0}‘ (gültig sind: ‚C‘, ‚C++‘, ‚D‘, ‚Windows‘, ‚Pascal‘, ‚System‘)",
  "erwartete eine oder mehrere Basisklassen, nicht ‚{0}‘",
  "Basisklassen sind in Vorwärtsdeklarationen nicht erlaubt",

  "ungültige UTF-8-Sequenz in Zeichenkette: ‚{}‘",
  "eine Moduldeklaration ist nur als allererste Deklaration in einer Datei erlaubt",
  "die Postfix-Zeichen in den Zeichenketten passen nicht zusammen",
  "der Bezeichner ‚{}‘ ist in einem Typ nicht erlaubt",
  "erwartete Bezeichner nach ‚(Typ).‘, nicht ‚{}‘",
  "erwartete Modulbezeichner, nicht ‚{}‘",
  "ungültige Deklaration gefunden: „{}“",
  "erwartete ‚system‘ oder ‚safe‘, nicht ‚{}‘",
  "erwartete Funktionsnamen, nicht ‚{}‘",
  "erwartete Variablenname, nicht ‚{}‘",
  "erwartete Funktionskörper, nicht ‚{}‘",
  "redundanter Anbindungstyp: ‚{}‘",
  "redundantes Zugriffsattribut: ‚{}‘",
  "erwartete einen Pragma-Bezeichner, nicht ‚{}‘",
  "erwartete einen Alias-Modulnamen, nicht ‚{}‘",
  "erwartete einen Aliasnamen, nicht ‚{}‘",
  "erwartete einen Bezeichner, nicht ‚{}‘",
  "erwartete ein Enummitglied, nicht ‚{}‘",
  "erwartete einen Enumkörper, nicht ‚{}‘",
  "erwartete einen Klassennamen, nicht ‚{}‘",
  "erwartete einen Klassenkörper, nicht ‚{}‘",
  "erwartete einen Interfacenamen, nicht ‚{}‘",
  "erwartete einen Interfacekörper, nicht ‚{}‘",
  "erwartete einen Structkörper, nicht ‚{}‘",
  "erwartete einen Unionkörper, nicht ‚{}‘",
  "erwartete einen Templatenamen, nicht ‚{}‘",
  "erwartete einen Bezeichner, nicht ‚{}‘",
  "ungültige Anweisung gefunden: „{}“",
  "erwartete nicht ‚;‘, verwende ‚{{ }‘ stattdessen",
  "erwartete ‚exit‘, ‚success‘ oder ‚failure‘, nicht ‚{}‘",
  "‚{}‘ ist kein gültiger Scopebezeichner (gültig sind: ‚exit‘, ‚success‘, ‚failure‘)",
  "erwartete ‚C‘, ‚C++‘, ‚D‘, ‚Windows‘, ‚Pascal‘ oder ‚System‘, aber nicht ‚{}‘",
  "erwartete einen Bezeichner nach ‚@‘",
  "unbekanntes Attribut: ‚@{}‘",
  "erwartete eine Ganzzahl nach align, nicht ‚{}‘",
  "ungültige Asm-Anweisung gefunden: „{}“",
  "ungültiger binärer Operator ‘{}’ in Asm-Anweisung",
  "erwartete einen Bezeichner für die Deklaration, nicht ‚{}‘",
  "erwartete einen oder mehrere Templateparameter, nicht ‚)‘",
  "erwartete einen Typ oder einen Ausdruck, nicht ‚)‘",
  "erwartete einen Namen für den Alias-Templateparameter, nicht ‚{}‘",
  "erwartete einen Namen für den ‚this‘-Templateparameter, nicht ‚{}‘",
  "erwartete einen Bezeichner oder eine Ganzzahl, nicht ‚{}‘",
  "der ‚try‘-Anweisung fehlt eine ‚catch‘- oder ‚finally‘-Anweisung",
  "erwartete schließende Klammer ‚{}‘ (‚{}‘ @{},{}), nicht ‚{}‘",
  "Initialisierer sind für ‚alias‘-Deklarationen nicht erlaubt",
  "erwartete eine Variablendeklaration in alias, nicht ‚{}‘",
  "erwartete eine Variablendeklaration in typedef, nicht ‚{}‘",
  "nur ein Ausdruck ist für den Start einer Case-Range-Anweisung erlaubt",
  "erwartete einen Standardwert für den Parameter ‚{}‘",
  "variadischer Parameter darf nicht ‚ref‘ oder ‚out‘ sein",
  "weitere Parameter nach einem variadischen Parameter sind nicht erlaubt",

  // Help messages:
  `dil v{0}
Copyright (c) 2007-2011, Aziz Köksal. Lizensiert unter der GPL3.

Befehle:
{1}
Geben Sie 'dil help <Befehl>' ein, um mehr Hilfe zu einem bestimmten Befehl zu
erhalten.

Kompiliert mit {2} v{3} am {4}.`,

  `Generiere ein XML- oder HTML-Dokument aus einer D-Quelltextdatei.
Verwendung:
  dil gen datei.d [Optionen]

Optionen:
  --syntax         : generiere Elemente für den Syntaxbaum
  --xml            : verwende XML-Format (voreingestellt)
  --html           : verwende HTML-Format

Beispiel:
  dil gen Parser.d --html --syntax > Parser.html`,

  ``,
];
