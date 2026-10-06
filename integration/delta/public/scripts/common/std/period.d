include "number.d"
include "date.d"

class Period
{
  static var YearForms => locale("date.year.plural.full") ?? ["", "", ""];
  static var MonthForms => locale("date.month.plural.full") ?? ["", "", ""];
  static var DayForms => locale("date.day.plural.full") ?? ["", "", ""];
  static var YearShort => locale("date.year.plural.short") ?? ["", "", ""];
  static var MonthShort => locale("date.month.plural.short") ?? ["", "", ""];
  static var DayShort => locale("date.day.plural.short") ?? ["", "", ""];

  /** Разбор yy.mmdd → [years, months, days] (как InterDatePeriod.DecodeYymmdd). */
  static List Decode(double val)
  {
    var scaled = (val.Abs() * 10000).Round();
    var years = scaled / 10000;
    var rem = scaled % 10000;
    var months = rem / 100;
    var days = rem % 100;
    if (val < 0)
      return [-years, -months, -days];
    return [years, months, days];
  }

  const YMD_DEFAULT      = 0x0000;
  const YMD_NUM_WORDS    = 0x0001; // Числа прописью
  const YMD_SNUM_WORDS   = 0x0002; // Дополнительная пропись числа в скобках
  const YMD_SNUM_UPWORDS = 0x0003; // Дополнительная пропись числа в скобках с большой буквы
  const YMD_SHORT        = 0x0004; // сокращенная запись
  const YMD_SHORTZ       = 0x0005; // сокращенная запись с отображением нулевых значений

  // NBSP before/after «с»/«по» in period text
  static string _nbsp => " ";

  /** Форматирование интервала дат (legacy ПЕРИОД_ПРОП).
   *  style 0 — 01.01.2000-31.12.2000; 1 — с … по …; 2 — с 01 по 31 января 2000 года;
   *  3 — с 01 января 2000 года по …; 4 — с 01.01.2000 года по …
   */
  static string PeriodInWords(date start, date end, int style = 0, int key = 0)
  {
    if (!start || !end)
      return "";

    var s = "с";
    var po = "по";
    var ds = string(start);
    var de = string(end);

    if (style == 0)
      return start == end ? ds : ds + "-" + de;

    if (style == 1)
      return start == end ? ds : s + _nbsp + ds + " " + po + _nbsp + de;

    if (style == 3)
    {
      if (start == end)
        return Date.InWords(start, key);
      return s + " " + Date.InWords(start, key) + " " + po + " " + Date.InWords(end, key);
    }

    if (style == 4)
    {
      if (start == end)
        return ds + " " + Date.FullYear;
      return s + _nbsp + ds + " " + Date.FullYear + " " + po + _nbsp + de + " " + Date.FullYear;
    }

    if (style == 2)
      return _periodStyle2(start, end, key, s, po);

    return ds + "-" + de;
  }

  static string _periodStyle2(date start, date end, int key, string s, string po)
  {
    if (start == end)
      return Date.InWords(start, key);

    if (start.Year == end.Year)
    {
      var sd = _periodDay(start, key);
      var ed = _periodDay(end, key);
      var yearSuffix = (key == 1 || key == 3) ? Date.ShortYear : Date.FullYear;

      if (start.Month == end.Month)
        return s + " " + sd + " " + po + " " + ed + " " + Date.InWords(start, -1) + " " + end.Year + " " + yearSuffix;

      return s + " " + sd + " " + Date.InWords(start, -1) + " " + po + " " + ed + " " + Date.InWords(end, -1) + " " + end.Year + " " + yearSuffix;
    }

    return s + " " + Date.InWords(start, key) + " " + po + " " + Date.InWords(end, key);
  }

  static string _periodDay(date val, int key)
  {
    var dd = val.Day;
    if (key == 0 || key == 1)
      return dd.Pad(2);
    if (key == 2 || key == 3)
      return "«" + dd.Pad(2) + "»";
    return string(dd);
  }

  /** Форматирование периодического значения
   *
   *  Представление периодического значения заданного в формате yy.mmdd
   *  в соответствии с выбранным способом форматирования
   *  \param   val    - периодическое значение в формате yy.mmdd
   *  \param   key    - способ форматирования (YMD_*)
   *  \param   ord    - порядковые в скобках: "1 (первого) года …"
   *  \return  форматированное представление периодического значения
   */
  static string InWords(double val, int key = YMD_DEFAULT, bool ord = false)
  {
    var parts = Decode(val);
    var ys = parts[0];
    var ms = parts[1];
    var ds = parts[2];

    if (key == YMD_SHORT)
    {
      string res = "";
      if (ys != 0)
        res = string(ys) + Number.WithUnit(ys, YearShort, Number.WU_UNIT_ONLY);
      if (ms != 0)
        res = res.Bind(string(ms) + Number.WithUnit(ms, MonthShort, Number.WU_UNIT_ONLY), " ");
      if (ds != 0)
        res = res.Bind(string(ds) + Number.WithUnit(ds, DayShort, Number.WU_UNIT_ONLY), " ");
      return res;
    }

    if (key == YMD_SHORTZ)
    {
      string res = string(ys) + Number.WithUnit(ys, YearShort, Number.WU_UNIT_ONLY);
      res = res.Bind(string(ms) + Number.WithUnit(ms, MonthShort, Number.WU_UNIT_ONLY), " ");
      res = res.Bind(string(ds) + Number.WithUnit(ds, DayShort, Number.WU_UNIT_ONLY), " ");
      return res;
    }

    if (ord)
    {
      string res = "";
      if (ys != 0)
        res = _ordPart(ys, YearForms);
      if (ms != 0)
        res = res.Bind(_ordPart(ms, MonthForms), " ");
      if (ds != 0)
        res = res.Bind(_ordPart(ds, DayForms), " ");
      return res;
    }

    var style = Number.WU_NUM_UNIT;
    var lower = false;
    if (key == YMD_NUM_WORDS)
      style = Number.WU_SNUM_UNIT;
    else if (key == YMD_SNUM_WORDS)
    {
      style = Number.WU_NUM_TEXT_UNIT;
      lower = true;
    }
    else if (key == YMD_SNUM_UPWORDS)
      style = Number.WU_NUM_TEXT_UNIT;

    string res = "";
    if (ys != 0)
    {
      var part = Number.WithUnit(ys, YearForms, style);
      res = lower ? part.ToLower() : part;
    }
    if (ms != 0)
    {
      var part = Number.WithUnit(ms, MonthForms, style);
      if (lower)
        part = part.ToLower();
      res = res.Bind(part, " ");
    }
    if (ds != 0)
    {
      var part = Number.WithUnit(ds, DayForms, style);
      if (lower)
        part = part.ToLower();
      res = res.Bind(part, " ");
    }
    return res;
  }

  /** "1 (первого) года" — единица в род.п. (forms[1]). */
  static string _ordPart(int n, List forms)
  {
    var unit = forms.Count() > 1 ? forms[1] : Number.Unit(n, forms);
    var words = Number.AsOrdinal(n, "gen.m");
    return string(n).Bind("(" + words + ")", " ").Bind(unit, Number.Join);
  }
}
