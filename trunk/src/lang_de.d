/++
  Author: Aziz Köksal
  License: GPL3
+/

string[] messages = [
  // Lexer messages:
  "ungültiges Unicodezeichen.",
  "ungültige UTF-8-Sequenz.",
  // ''
  "unterminiertes Zeichenliteral.",
  "leeres Zeichenliteral.",
  // #line
  "erwartete 'line' nach '#'.",
  `die Dateispezifikation (filespec) muss in Anführungszeichen angegeben werden (z.B. "filespec".)`,
  "Ganzzahl nach #line erwartet.",
  "Zeilenumbrüche innerhalb eines Special Token sind nicht erlaubt.",
  "ein Special Token muss mit einem Zeilenumbruch abgeschlossen werden.",
  // ""
  "unterminiertes Zeichenkettenliteral.",
  // x""
  "Nicht-Hexzeichen '{1}' in Hexzeichenkette gefunden.",
  "ungerade Anzahl von Hexziffern in Hexzeichenkette.",
  "unterminierte Hexzeichenkette.",
  // /* */ /+ +/
  "unterminierter Blockkommentar (/* */).",
  "unterminierter verschachtelter Kommentar (/+ +/).",
  // `` r""
  "unterminierte rohe Zeichenkette.",
  "unterminierte Backquote-Zeichenkette.",
  // \x \u \U
  "undefinierte Escapesequenz gefunden.",
  "unzureichende Anzahl von Hexziffern in Escapesequenz.",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "undefinierte HTML-Entität '{1}'",
  "unterminierte HTML-Entität.",
  "HTML-Entitäten müssen mit einem Buchstaben beginnen.",
  // integer overflows
  "Dezimalzahl überläuft im Vorzeichenbit.",
  "Überlauf in Dezimalzahl.",
  "Überlauf in Hexadezimalzahl.",
  "Überlauf in Binärzahl.",
  "Überlauf in Oktalzahl.",
  "Überlauf in Fließkommazahl.",
  "die Ziffern 8 und 9 sind in Oktalzahlen verboten.",
  "ungültige Hexzahl; mindestens eine Hexziffer erforderlich.",
  "ungültige Binärzahl; mindestens eine Binärziffer erforderlich.",
  "der Exponent einer hexadezimalen Fließkommazahl ist erforderlich.",
  "fehlende Dezimalzahlen im Exponent der hexadezimalen Fließkommazahl.",
  "Exponenten müssen mit einer Dezimalziffer anfangen.",

  // Parser messages:
  "erwartete '{1}', fand aber '{2}'.",
  "'{1}' ist redundant.",

  // Help messages:
  `dil v{1}
Copyright (c) 2007, Aziz Köksal. Lizensiert unter der GPL3.

Befehle:
  {2}

Geben Sie 'dil help <Befehl>' ein, um mehr Hilfe zu einem bestimmten Befehl zu
erhalten.

Kompiliert mit {3} v{4} am {5}.
`
];