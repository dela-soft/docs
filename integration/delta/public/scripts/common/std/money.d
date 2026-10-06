include "number.d"

/** Обработка денежных данных */
class Money
{
  // NBSP (U+00A0) thousand grouping
  static string Nbsp => " ";
  static string DecimalSep => ".";
  static string GroupSep => " ";

  /** Округление до копеек (legacy ОКРУГЛИТЬ_КОП). */
  static double RoundKopecks(double val)
    => val.Round(2);

  static int Rubles(double val) => _split(val).rub;
  static int Kopecks(double val) => _split(val).kop;

  /** Число с группировкой тысяч + unit (legacy ФОРМАТ_СУММЫ). */
  static string FormatAmount(double val, int key = 0, List? unitForms = null)
  {
    var n = _split(val).rub;
    var res = _formatGrouped(n);

    if (key == 1 || key == 2)
    {
      if (n != 0)
      {
        var words = Number.AsWords(n);
        if (key == 2)
          words = words.ToUpperFirst();
        res = res + " (" + words + ")";
      }
      else
        res = "0 (нуль)";
    }

    if (_hasUnit(unitForms))
    {
      var unit = Number.Unit(n, unitForms);
      if (unit != "")
        res = res.Bind(unit, " ");
    }

    return res;
  }

  /** «1 234.50» */
  static string FormatRub(double val, bool showZero = true)
  {
    var parts = _split(val);
    if (parts.rub == 0 && parts.kop == 0 && !showZero)
      return "";

    var res = _formatGrouped(parts.rub) + DecimalSep;
    if (parts.kop < 10)
      res = res + "0";
    return res + string(parts.kop);
  }

  /// Копейки прописью
  static string InWordsKopecks(int val, int key = 1, List? forms = null)
  {
    if (key == 6)
      return string(val) + Nbsp + "коп.";
    if (!_hasUnit(forms))
      return string(val);
    if (key == 0)
      return Number.WithUnit(val, forms, Number.WU_UNIT_ONLY);
    if (key == 2)
      return Number.WithUnit(val, forms, Number.WU_SNUM_UNIT);
    return Number.WithUnit(val, forms, Number.WU_NUM_UNIT);
  }

  /** Сумма прописью/цифрами */
  static string InWords(double val, int key = 0, List? rubForms = null, List? kopForms = null)
  {
    var parts = _split(val);
    var rub = parts.rub;
    var kop = parts.kop;

    if (key == -1)
    {
      var head = rub != 0 ? _formatGrouped(rub) : "0";
      return head + " руб. " + string(kop) + " коп.";
    }

    if (key != 0)
      return FormatRub(val);

    if (!_hasUnit(rubForms))
    {
      var res = rub != 0 ? _formatGrouped(rub) : "0";
      res = res + ".";
      if (kop < 10)
        res = res + "0";
      return res + string(kop);
    }

    string text = "";
    if (rub != 0 || kop == 0)
      text = FormatAmount(rub, 0, rubForms);
    if (kop != 0)
    {
      var kopKey = _shortRub(rubForms) ? 6 : 1;
      var kopText = InWordsKopecks(kop, kopKey, kopForms);
      text = text.Length == 0 ? kopText : text.Bind(kopText, " ");
    }
    return text;
  }

  static bool _hasUnit(List? forms)
    => forms != null && forms.Count() > 0 && (forms[0] ?? "") != "";

  static bool _shortRub(List? forms)
    => forms != null && forms.Count() > 0 && forms[0] == "руб.";

  static var _split(double val)
  {
    val = RoundKopecks(val);
    var neg = val < 0;
    if (neg)
      val = -val;
    var total = int((val * 100.0).Round());
    var rub = total / 100;
    var kop = total % 100;
    if (neg)
      rub = -rub;
    return { rub: rub, kop: kop };
  }

  static string _formatGrouped(int value)
  {
    if (value == 0)
      return "0";

    var sign = "";
    var n = value;
    if (n < 0)
    {
      sign = "-";
      n = -n;
    }

    var s = string(n);
    var len = s.Length;
    if (len <= 3)
      return sign + s;

    var first = len % 3;
    if (first == 0)
      first = 3;

    var res = s.Substring(0, first);
    for (var i = first; i < len; i += 3)
      res = res + GroupSep + s.Substring(i, 3);

    return sign + res.Replace(" ", Nbsp);
  }
}
