/** Number → words (tables from .locale/number.*.json). Forms: nom.m / nom.f / gen.m / gen.f */
class Number
{
  static string DefaultForm => locale("number.defaultForm") ?? "nom.m";
  static string Zero => locale("number.zero") ?? "0";
  static string Minus => locale("number.minus") ?? "-";
  static string Join => locale("number.join") ?? " ";
  static var GenderedOnes => locale("number.genderedOnes") ?? true;
  static var Forms => locale("number.forms");
  static var Scales => locale("number.scales") ?? [];
  static var Ordinals => locale("number.ordinals");

  /** Cardinal number in words.
   *  \param form  "nom.m" | "nom.f" | "gen.m" | "gen.f" (or "nom" / "gen"; gender from scale)
   */
  static string AsWords(int value, string form = "")
  {
    if (form == "")
      form = DefaultForm;

    if (value == 0)
      return Zero;

    if (value < 0)
      return Minus.Bind(AsWords(-value, form), Join);

    var scales = Scales;
    var chunks = _chunks1000(value);

    string res = "";
    for (var i = chunks.Count() - 1; i >= 0; i--)
    {
      var chunk = chunks[i];
      if (chunk == 0)
        continue;

      var scale = i < scales.Count() ? scales[i] : null;
      var gender = scale != null ? (scale.gender ?? "m") : "m";
      var useForm = _resolveForm(form, gender);
      var words = _spell999(chunk, useForm);

      if (scale != null && i > 0)
      {
        var plural = scale.plural ?? ["", "", ""];
        var unit = chunk.Plural(plural);
        if (unit != "")
          words = words.Bind(unit, Join);
      }

      res = res.Bind(words, Join);
    }

    return res;
  }

  /** Ordinal number in words.
   *  \param form  nom.m|f|n / gen.m|f|n — last significant part is ordinal; higher scales cardinal.
   *  Without ordinal locale tables → English-style suffix (1st, 2nd, …).
   */
  static string AsOrdinal(int value, string form = "")
  {
    if (form == "")
      form = DefaultForm;
    form = _normalizeOrdinalForm(form);

    var ord = Ordinals;
    if (ord == null || ord.forms == null)
      return _asOrdinalSuffix(value);

    if (value == 0)
      return _ordinalZero(form);

    if (value < 0)
      return Minus.Bind(AsOrdinal(-value, form), Join);

    var scales = Scales;
    var chunks = _chunks1000(value);
    var low = 0;
    while (low < chunks.Count() && chunks[low] == 0)
      low++;

    string res = "";
    for (var i = chunks.Count() - 1; i > low; i--)
    {
      var chunk = chunks[i];
      if (chunk == 0)
        continue;

      var scale = i < scales.Count() ? scales[i] : null;
      var gender = scale != null ? (scale.gender ?? "m") : "m";
      var words = _spell999(chunk, _resolveForm("nom", gender));
      if (scale != null && i > 0)
      {
        var plural = scale.plural ?? ["", "", ""];
        var unit = chunk.Plural(plural);
        if (unit != "")
          words = words.Bind(unit, Join);
      }
      res = res.Bind(words, Join);
    }

    if (low == 0)
      return res.Bind(_spell999Ordinal(chunks[0], form), Join);

    // Exact multiple of 1000^low (e.g. 2000 → двухтысячный).
    if (low == 1 && chunks[1] >= 1 && chunks[1] <= 9)
    {
      var exact = _thousandsExact(chunks[1], form);
      if (exact != "")
        return res.Bind(exact, Join);
    }

    // Fallback: cardinal chunk + ordinal ones of 1 at that scale is wrong;
    // spell chunk as ordinal ones when <1000 and append scale cardinal plural stem — keep simple:
    // treat as ordinal of chunk with nominative scale word omitted for low>1.
    var lowChunk = chunks[low];
    var scaleLow = low < scales.Count() ? scales[low] : null;
    var wordsLow = _spell999Ordinal(lowChunk, form);
    if (scaleLow != null && low > 0)
    {
      var plural = scaleLow.plural ?? ["", "", ""];
      // «двадцать одна тысячная» — unit from ordinal gender; use first plural form as stem fallback.
      var unit = plural.Count() > 0 ? plural[0] : "";
      if (unit != "")
        wordsLow = wordsLow.Bind(unit, Join);
    }
    return res.Bind(wordsLow, Join);
  }

  /** CSV → List as-is (no pad). "" → []; "a" → ["a"]; "a,b" → ["a","b"]. */
  static List ParseForms(string csv)
  {
    if (csv == "")
      return [];

    var parts = csv.Split(",");
    var res = [];
    for (var i = 0; i < parts.Count(); i++)
      res.Add(parts[i].Trim());
    return res;
  }

  /** Unit word for value from forms list (ru: 3, en: often 2; short list → last / ""). */
  static string Unit(int value, List forms)
    => value.Plural(forms);

  const WU_UNIT_ONLY = 0;
  const WU_NUM_UNIT = 1;
  const WU_SNUM_UNIT = 2;
  const WU_NUM_TEXT_UNIT = 3;
  const WU_NUM_GTEXT_UNIT = 4;
  
  /** Number + unit by key (legacy ПРОПИСЬ keys 0…4; 5 ≡ 0).
   *  0 — unit only; 1 — "10 рублей"; 2 — "десять рублей";
   *  3 — "10 (Десять) рублей"; 4 — "10 (Десяти) рублей" (genitive words).
   */
  static string WithUnit(int value, List forms, int key = WU_NUM_UNIT)
  {
    var unit = Unit(value, forms);
    if (key == WU_UNIT_ONLY)
      return unit;

    if (key == WU_NUM_UNIT)
      return string(value).Bind(unit, Join);

    if (key == WU_SNUM_UNIT)
      return AsWords(value).Bind(unit, Join);

    if (key == WU_NUM_TEXT_UNIT)
    {
      var words = AsWords(value).ToUpperFirst();
      return string(value).Bind("(" + words + ")", " ").Bind(unit, Join);
    }

    if (key == WU_NUM_GTEXT_UNIT)
    {
      var words = AsWords(value, "gen.m").ToUpperFirst();
      return string(value).Bind("(" + words + ")", " ").Bind(unit, Join);
    }

    return WithUnit(value, forms, WU_NUM_UNIT);
  }

  /** Ones table key: case from form, feminine if form ends with .f or scale gender is f. */
  static string _resolveForm(string form, string gender)
  {
    var isGen = form.StartsWith("gen");
    if (GenderedOnes == false)
      return isGen && _formsHas("gen.m") ? "gen.m" : DefaultForm;

    var fem = form.EndsWith(".f") || gender == "f";
    if (isGen && fem)
      return "gen.f";
    if (isGen)
      return "gen.m";
    if (fem)
      return "nom.f";
    return "nom.m";
  }

  static bool _formsHas(string form)
  {
    var forms = Forms;
    if (forms == null)
      return false;
    return forms.Has(form);
  }

  static string _spell999(int n, string form)
  {
    var table = _formTable(form);
    var ones = table.ones ?? [""];
    var teens = table.teens ?? [""];
    var tens = table.tens ?? [""];
    var hundreds = table.hundreds ?? [""];

    string res = "";
    var h = n / 100;
    if (h > 0)
      res = hundreds[h] ?? "";

    var rem = n % 100;
    if (rem >= 10 && rem <= 19)
      return res.Bind(teens[rem - 10] ?? "", Join);

    var t = rem / 10;
    var o = rem % 10;
    if (t >= 2)
      res = res.Bind(tens[t] ?? "", Join);
    if (o > 0)
      res = res.Bind(ones[o] ?? "", Join);
    return res;
  }

  static var _formTable(string form)
  {
    var forms = Forms;
    if (forms == null)
      return { ones: [""], teens: [""], tens: [""], hundreds: [""] };

    var table = forms[form];
    if (table == null)
      table = forms[DefaultForm];
    if (table == null)
      return { ones: [""], teens: [""], tens: [""], hundreds: [""] };
    return table;
  }

  static List _chunks1000(int value)
  {
    var chunks = [];
    var n = value;
    while (true)
    {
      chunks.Add(n % 1000);
      n = n / 1000;
      if (n == 0)
        break;
    }
    return chunks;
  }

  static string _normalizeOrdinalForm(string form)
  {
    if (form == "nom" || form == "nom.m")
      return "nom.m";
    if (form == "gen" || form == "gen.m")
      return "gen.m";
    return form;
  }

  static string _ordinalZero(string form)
  {
    var zero = Ordinals?.zero;
    if (zero == null)
      return Zero;
    return zero[form] ?? zero[DefaultForm] ?? Zero;
  }

  static string _thousandsExact(int n, string form)
  {
    var table = Ordinals?.thousandsExact;
    if (table == null)
      return "";
    var row = table[form] ?? table[DefaultForm];
    if (row == null)
      return "";
    return row[n] ?? "";
  }

  /** 0…999: last word ordinal; hundreds/tens before it stay nominative cardinal. */
  static string _spell999Ordinal(int n, string form)
  {
    var otable = _ordinalFormTable(form);
    var ones = otable.ones ?? [""];
    var teens = otable.teens ?? [""];
    var tens = otable.tens ?? [""];
    var hundreds = otable.hundreds ?? [""];
    var card = _formTable("nom.m");
    var cardHundreds = card.hundreds ?? [""];
    var cardTens = card.tens ?? [""];

    var h = n / 100;
    var rem = n % 100;

    if (rem == 0)
      return h > 0 ? (hundreds[h] ?? "") : "";

    string res = h > 0 ? (cardHundreds[h] ?? "") : "";

    if (rem >= 10 && rem <= 19)
      return res.Bind(teens[rem - 10] ?? "", Join);

    var t = rem / 10;
    var o = rem % 10;
    if (o == 0)
      return res.Bind(tens[t] ?? "", Join);

    if (t >= 2)
      res = res.Bind(cardTens[t] ?? "", Join);
    return res.Bind(ones[o] ?? "", Join);
  }

  static var _ordinalFormTable(string form)
  {
    var forms = Ordinals?.forms;
    if (forms == null)
      return { ones: [""], teens: [""], tens: [""], hundreds: [""] };

    var table = forms[form];
    if (table == null)
      table = forms[DefaultForm];
    if (table == null)
      return { ones: [""], teens: [""], tens: [""], hundreds: [""] };
    return table;
  }

  /** en / no-table fallback: 1st, 2nd, 3rd, 11th… */
  static string _asOrdinalSuffix(int value)
  {
    if (value < 0)
      return Minus.Bind(_asOrdinalSuffix(-value), Join);

    var n = value;
    var mod100 = n % 100;
    var mod10 = n % 10;
    string suf = "th";
    if (mod100 < 11 || mod100 > 13)
    {
      if (mod10 == 1)
        suf = "st";
      else if (mod10 == 2)
        suf = "nd";
      else if (mod10 == 3)
        suf = "rd";
    }
    return string(n) + suf;
  }
}
