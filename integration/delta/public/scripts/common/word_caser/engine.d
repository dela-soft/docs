include "handler.d"

/// Table-driven inflection engine: row = [form, case1…caseN, filter].
/// Locales supply _cases / CaseSlot (letters); engine uses slots + last-column filter.
class WordCaserEngine : WordCaserHandler
{
  /// Number of case columns (slots 1…CaseCount). Filter is always last.
  int CaseCount => 6;

  /// Index of the letter-filter / "..." list column.
  int FilterSlot => CaseCount + 1;

  /// Case letter → slot. Cyrillic (И Р Д В Т П) and Latin (N G D A I P).
  /// Override when the locale uses other marks.
  int CaseSlot(string wCase) => wCase switch
  {
    "И" or "N" => 1, // nominative
    "Р" or "G" => 2, // genitive
    "Д" or "D" => 3, // dative
    "В" or "A" => 4, // accusative
    "Т" or "I" => 5, // instrumental
    "П" or "P" => 6, // prepositional
    _ => 0,
  };

  string _internalWordCase(string form, string word, string wCase)
  {
    if (!word)
      return "";

    var slot = CaseSlot(wCase);
    // Nominative (slot 1): keep the original word; unknown letter: no-op.
    if (slot <= 1)
      return word;

    var filter = FilterSlot;
    var sword = word.ToLower();
    var n = _cases.Count();
    for (var i = 0; i < n; i++)
    {
      var row = _cases[i];
      var end = row[1];
      var len = end.Length;
      var ok = true;
      if (len != 0)
        ok = sword.EndsWith(end);

      if (ok)
      {
        if (row[0] == "...")
        {
          ok = sword in row[filter];
        }
        else
        {
          if (form)
            ok = row[0] == form;

          if (ok)
          {
            var letters = row[filter];
            if (letters)
            {
              if (sword.Length <= len)
                ok = false;
              else
                ok = letters.IndexOf(sword[sword.Length - len - 1]) >= 0;
            }
          }
        }

        if (ok)
        {
          var stem = len == 0 ? word : word.Substring(0, word.Length - len);
          return $"{stem}{row[slot]}";
        }
      }
    }
    return word;
  }

  string _internalNameCase(int mode, string text, string wCase, bool female)
    => _internalWordCase($"{mode}{(female ? "f" : "m")}", text, wCase);

  string _doProcessing(string data, string wCase, string formPrefix)
  {
    var parts = [];
    var i = 0;
    var n = data.Length;
    var freeze = false;
    var seenNoun = false;
    while (i < n)
    {
      var ch = data[i];
      if (ch == ' ')
      {
        parts.Add(" ");
        i++;
        continue;
      }

      if (ch in ['"', '(', '«'])
      {
        var endCh = ch == '"' ? "\"" : (ch == '(' ? ")" : "»");
        var rest = data.Substring(i + 1);
        var pos = rest.IndexOf(endCh);
        if (pos < 0)
          return string.Join("", parts) + data.Substring(i);
        parts.Add(data.Substring(i, pos + 2));
        i = i + pos + 2;
        continue;
      }

      var start = i;
      while (i < n)
      {
        var c = data[i];
        if (c in [' ', '"', '(', '«'])
          break;
        i++;
      }
      var lex = data.Substring(start, i - start);
      var form = GetWordForm(lex);
      if (form == "-")
        freeze = true;
      // "и": coordinated nouns (e.g. "Бухгалтерия и финансы") — inflect the next head again
      if (lex.ToLower() == "и")
        seenNoun = false;
      var skip = freeze || form == "-" || lex.Length <= 2;
      if (!skip)
        skip = formPrefix == "#" ? IsPostExceptionWord(lex) : IsExceptionWord(lex);
      // After the first noun, the rest of the phrase is already in the target case
      if (!skip)
      {
        if (formPrefix != "#")
        {
          if (seenNoun)
            skip = true;
          else
          {
            if (form == "n")
              seenNoun = true;
          }
        }
      }
      if (skip)
        parts.Add(lex);
      else
        parts.Add(_internalWordCase($"{formPrefix}{form}", lex, wCase));
    }
    return string.Join("", parts);
  }

  string _partAt(List parts, int i)
    => parts.Count() > i ? parts[i] : "";

  string _snpFull(string s, string n, string p)
    => string.Join(" ", [s, n, p].Where(x => x));

  string _snpUpSurname(string s, string n, string p)
    => string.Join(" ", [s.ToUpper(), n, p].Where(x => x));

  string _snpInitialsRight(string s, string initials)
    => string.Join(" ", [s, initials].Where(x => x));

  string _snpInitialsLeft(string initials, string s) => $"{initials}{s}";

  string _initialsOf(string n, string p)
  {
    var initials = "";
    if (n.Length > 0)
      initials = initials + n[0] + ".";
    if (p.Length > 0)
      initials = initials + p[0] + ".";
    return initials;
  }

  string _doSnpCase(string snp, string wCase, int form)
  {
    var parts = snp.Split(" ");
    var s = _partAt(parts, 0);
    var n = _partAt(parts, 1);
    var p = _partAt(parts, 2);
    var p1 = _partAt(parts, 3);

    var female = false;
    if (p.Length != 1)
      female = p.ToLower().EndsWith("а");
    if (p1.Length)
    {
      p = $"{p} {p1}";
      if (!female)
        female = s.ToLower().EndsWith("а");
    }

    var style = form & SnpStyleMask;
    var state = form & SnpPartsMask;
    if (state == 0)
      state = SnpAllParts;

    if ((state & SnpSurname) != 0)
      s = _internalNameCase(1, s, wCase, female);
    else
      s = "";
    if ((state & SnpName) != 0)
      n = _internalNameCase(2, n, wCase, female);
    else
      n = "";
    if ((state & SnpPatronymic) != 0)
      p = _internalNameCase(3, p, wCase, female);
    else
      p = "";

    var initials = _initialsOf(n, p);
    return style switch
    {
      0 => _snpFull(s, n, p),
      1 => _snpUpSurname(s, n, p),
      2 => _snpInitialsRight(s, initials),
      3 => _snpInitialsRight(s.ToUpper(), initials),
      4 => _snpInitialsLeft(initials, s),
      5 => _snpInitialsLeft(initials, s.ToUpper()),
      _ => _snpFull(s, n, p),
    };
  }
}
