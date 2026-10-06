include "number.d"

/** Форматирование дат (суффиксы/plural из .locale/date.*.json) */
class Date
{
  static List PluralFullYear => locale("date.year.plural.full") ?? ["", "", ""];
  static List PluralShortYear => locale("date.year.plural.short") ?? ["", "", ""];
  static string FullYear => locale("date.year.suffix.full") ?? "";
  static string ShortYear => locale("date.year.suffix.short") ?? "";
  static string QuarterLabel => locale("date.quarter.label") ?? "";

  /** Месяц в родительном падеже (января) — через ICU Format. */
  static string GenitiveMonthName(date val) => val.Format("dd MMMM").Substring(3);

  /** «I квартал 2003 года» / «I quarter 2003». */
  static string QuarterInWords(date val)
    => $"{val.Quarter.ToRoman()} {QuarterLabel} {val.Year} {FullYear}";

  /** Форматирование датируемого значения
   *
   *  Представление датируемого значения в соответствующем параметру формате
   *  \param   val     - датируемое значение
   *  \param   key     - параметр форматирования
   *   \value  -1      - января
   *   \value  0       - 01 января 2003 года
   *   \value  1       - 01 января 2003 г.
   *   \value  2       - «01» января 2003 года
   *   \value  3       - «01» января 2003 г.
   *   \value  100     - 1 января 2003 года
   *   \value  101     - 1 января 2003 г.
   *   \value  102     - «   » января 2003 года
   *   \value  103     - «   » января 2003 г.
   *   \value  110     - 1 января
   *   \value  111     - 01 января
   *   \value  120     - январь 2003
   *   \value  121     - январь 2003 года
   *   \value  122     - январь 2003 г.
   *   \value  130     - I квартал 2003 года
   *   \value  140     - первое января две тысячи третьего года
   *   \value  141     - первого января две тысячи третьего года
   *  \return  форматированное представление датируемого значения
   */
  static string InWords(date val, int key, string def = "_________________")
  {
    if(val == 0)
      return def;

    var dd = val.Day;
    var yy = val.Year;
    var ms = GenitiveMonthName(val);

    return key switch
    {
       -1 => ms,
        0 => $"{dd.Pad(2)} {ms} {yy} {FullYear}",
        1 => $"{dd.Pad(2)} {ms} {yy} {ShortYear}",
        2 => $"«{dd.Pad(2)}» {ms} {yy} {FullYear}",
        3 => $"«{dd.Pad(2)}» {ms} {yy} {ShortYear}",
      100 => $"{dd} {ms} {yy} {FullYear}",
      101 => $"{dd} {ms} {yy} {ShortYear}",
      102 => $"«     » {ms} {yy} {FullYear}",
      103 => $"«     » {ms} {yy} {ShortYear}",
      110 => $"{dd} {ms}",
      111 => $"{dd.Pad(2)} {ms}",
      120 => val.Format("MMMM yyyy"),
      121 => val.Format("MMMM yyyy")+" "+FullYear,
      122 => val.Format("MMMM yyyy")+" "+ShortYear,
      130 => QuarterInWords(val),
      140 => $"{Number.AsOrdinal(dd, "nom.n")} {ms} {Number.AsOrdinal(yy, "gen.m")} {FullYear}",
      141 => $"{Number.AsOrdinal(dd, "gen.n")} {ms} {Number.AsOrdinal(yy, "gen.m")} {FullYear}",
        _ => def,
    };
  }
}
