include "std/number.d"
include "std/date.d"
include "std/period.d"
include "std/money.d"
include "word_caser/ru"

/// Инициализация переменной числовым значением
void СБРОС(string name, int val=0)
{
  $[name]=val; 
}

/// Инициализация переменной строковым значением
void ПЕРЕМ(string name,var val)
{
  $[name]=val; 
}
  
/// Накапливает значения переменной и возвращает ее значение 
int ИТОГ(string name, int val)
{
  return $[name]+=val;
}

/// Накапливает значения переменной
void НАКОПИТЬ(string name, int val)
{  
  $[name]+=val; 
}

/// Чтение значения поля текущей таблицы
var ПОЛЕ(string name)
{
  return Editor.Field(name) ?? "";
}

/// Текущая дата
date ДАТА => date.Today();

/// Форматированный вывод даты прописью
string ДАТА_ПРОП(date val, int key=0, string def = "_________________")
  => Date.InWords(val, key, def);

/** Форматирование периодического значения 
 *
 *  Представление периодического значения заданного в формате yy.mmdd 
 *  в соответствии с выбранным способом форматирования
 *  \param   val    - периодическое значение в формате yy.mmdd 
 *  \param   style  - способ форматирования
 *   \value  YMD_DEFAULT      - параметры периода (год, месяц, день) прописью "1 год 5 месяцев 6 дней"
 *   \value  YMD_NUM_WORDS    - период прописью "один год пять месяцев шесть дней"
 *   \value  YMD_SNUM_WORDS   - период прописью "1 (один) год 5 (пять) месяцев 6 (шесть) дней"
 *   \value  YMD_SNUM_UPWORDS - период прописью "1 (Один) год 5 (Пять) месяцев 6 (Шесть) дней"
 *   \value  YMD_SHORT        - период в сокращенной записи "1г 5м 6д"
 *   \value  YMD_SHORTZ       - период в сокращенной записи с отображением нулевых значений "1г 0м 6д"
 *  \param   ord    - форматирование чисел порядковыми знчениями. "1 (первого) года 5 (пятого) месяца 6 (шестого) дня" 
 *  \return  форматированное представление периодического значения
 */
string ЛЕТ_МЕС_ДНЕЙ(double val, int key=Period.YMD_DEFAULT, bool ord=false)
  => Period.InWords(val, key, ord);

/** Форматирование значения периода между двумя датами 
 *
 *  Форматирование значения периода от даты <b>start</b> до <b>end</b>
 *  \param   start  - значение первой даты
 *  \param   end    - значение второй даты
 *  \param   key    - стиль форматирования. см: ЛЕТ_МЕС_ДНЕЙ
 *  \param   ord    - форматирование чисел порядковыми знчениями 
 *  \return  форматированное представление периодического значения
 */
string ПЕРИОД_СТР(date start, date end, int key = Period.YMD_DEFAULT, bool ord = false)
  => (start && end)? Period.InWords(start.Diff(end + 1), key, ord) : "";

/** Форматирование представления периода между двумя датами
 *
 *  \param   start   - начало периода
 *  \param   end     - окончание периода
 *  \param   style   - вариант форматирования (0..4, см. Period.PeriodInWords)
 *  \param   key     - вариант представления даты прописью (как ДАТА_ПРОП)
 *  \return  форматированное представление значения периода
 */
string ПЕРИОД_ПРОП(date start, date end, int style = 0, int key = 0)
  => Period.PeriodInWords(start, end, style, key);

/// ФИО сотрудника в виде инициалов
string ИНИЦИАЛЫ(string snp, var left=false) 
  => WordCaser.SnpCase(snp, "И", left? 4 : 2);
  
/// Склонение фразы
string ПАДЕЖ(string str, string wCase) 
  => wCase=="И"? str : WordCaser.Processing(str, wCase);

/// Падежирование фамилии, имени, отчества
string ПАДЕЖ_ФИО(string snp, string wCase, int form = 0)
  => WordCaser.SnpCase(snp, wCase, form);

/// Падежирование должности
string ПАДЕЖ_ДЛЖ(string post, string wCase) 
  => wCase=="И"? post : WordCaser.PostCase(post, wCase);
  
/// Приведение первого символа к нижнему регистру  
string МАЛ(string text) 
  => text.ToLowerFirst();

/// Приведение строки к нижнему регистру  
string ВСЕ_МАЛ(string text) 
  => text.ToLower();

/// Приведение первого символа к верхнему регистру  
string ЗАГ(string text) 
  => text.ToUpperFirst();

/// Приведение строки к верхнему регистру  
string ЗАГЛАВ(string text) 
  => text.ToUpper();

/// Прямые кавычки → « »
string КАВЫЧКИ(string text)
  => text.SmartQuotes();

/// AsText form → std Number form (nom.m / nom.f / gen.m / gen.f)
string _mapNumberForm(string form)
{
  if (form == "")
    return "";

  return form.ToUpper() switch
  {
    "И" => "nom.m",
    "Ж" => "nom.f",
    "Р" => "gen.m",
    "Р,Ж" => "gen.f",
    _ => form,
  };
}

/// AsOrdinal form → nom/gen + m/f/n ("И,с" → nom.n, "Р.м" → gen.m)
string _mapOrdinalForm(string form)
{
  if (form == "")
    return "nom.m";

  var key = form.ToUpper().Replace(".", ",");
  return key switch
  {
    "И" or "И,М" => "nom.m",
    "И,Ж" => "nom.f",
    "И,С" => "nom.n",
    "Р" or "Р,М" => "gen.m",
    "Р,Ж" => "gen.f",
    "Р,С" => "gen.n",
    _ => form,
  };
}

/// Число прописью (form: "и" / "Р" / "ж" / "Р,ж")
string ЧИСЛО_ПРОП(int value, string form = "")
  => Number.AsWords(value, _mapNumberForm(form));

/// Порядковое число прописью (form: "И,с" / "Р,м" / nom.n / …)
string ПОРЯДКОВОЕ(int value, string form = "")
  => Number.AsOrdinal(value, _mapOrdinalForm(form));

/// Формы единицы [one, few, many] по аббревиатуре
List ПРОПИСЬ_ПАРАМ(string param)
{
  if (param == "")
    return ["", "", ""];

  return param switch
  {
    "год" => ["год", "года", "лет"],
    "месяц" => ["месяц", "месяца", "месяцев"],
    "неделя" => ["неделя", "недели", "недель"],
    "день" or "дн" => ["день", "дня", "дней"],
    "кд" => ["календарный день", "календарных дня", "календарных дней"],
    "кд.р" => ["календарного дня", "календарных дней", "календарных дней"],
    "рд" => ["рабочий день", "рабочих дня", "рабочих дней"],
    "час" => ["час", "часа", "часов"],
    "мин" => ["минута", "минуты", "минут"],
    "сек" => ["секунда", "секунды", "секунд"],
    "руб" => ["рубль", "рубля", "рублей"],
    "руб.р" => ["рубля", "рублей", "рублей"],
    "р." => ["руб.", "руб.", "руб."],
    "б.руб" => ["белорусский рубль", "белорусских рубля", "белорусских рублей"],
    "коп" => ["копейка", "копейки", "копеек"],
    "коп.р" => ["копейки", "копеек", "копеек"],
    "доллар" => ["доллар", "доллара", "долларов"],
    "%" => ["процент", "процента", "процентов"],
    "чел" => ["человек", "человека", "человек"],
    "курс" => ["курс", "курса", "курса"],
    "б.в." => ["базовая величина", "базовые величины", "базовых величин"],
    "б.в.4" => ["базовой величины", "базовых величин", "базовых величин"],
    "б.ст." => ["базовая ставка", "базовые ставки", "базовых ставок"],
    "б.ст.4" => ["базовой ставки", "базовых ставок", "базовых ставок"],
    "доп.дн" => ["дополнительный день", "дополнительных дня", "дополнительных дней"],
    "о.дн" => ["оплачиваемый день", "оплачиваемых дня", "оплачиваемых дней"],
    "п.дн" => ["праздничный день", "праздничных дня", "праздничных дней"],
    "доп.св" => ["дополнительный свободный от работы день", "дополнительных свободных от работы дня", "дополнительных свободных от работы дней"],
    "пред-ый" => ["предоставленный", "предоставленные", "предоставленных"],
    _ => Number.ParseForms(param),
  };
}

/** Форматирование числового значения с дополнением соответствующими ему параметрами (см. Number.WithUnit)
 *  \param   val     - числовое значение
 *  \param   param   - дополнительный параметр числа см: ПРОПИСЬ_ПАРАМ
 *  \param   style   - способ форматирования
 *   \value  0       - возвращается только параметр числа
 *   \value  1       - значение числа и его параметр. "10 рублей"
 *   \value  2       - значение числа прописью и его параметр. "десять рублей"
 *   \value  3       - значение числа дополняется прописью в скобках. "10 (Десять) рублей"
 *   \value  4       - значение числа дополняется прописью в скобках в родительном падеже. 
 *                     "10 (Десяти) рублей"
 *   \value  5       - значение параметра без числа. "рублей"
 *  \param   keys    - ключи форматирования
 *   \value  0x01    - преобразования значения к нижнему регистру
 *   \value  0x02    - в виде порядковых
 *  \return  форматированное представление числового значения
 */
string ПРОПИСЬ(int val, string param, int style = 1, int keys = 0)
{
  if ((keys & 0x02) != 0)
  {
    var forms = ПРОПИСЬ_ПАРАМ(param);
    var unit = Number.Unit(val, forms);
    if (style == 0 || style == 5)
      return unit;

    var ordForm = style == 4 ? "gen.m" : "nom.m";
    if (style == 2)
    {
      var res2 = Number.AsOrdinal(val, ordForm).Bind(unit, Number.Join);
      return (keys & 0x01) != 0 ? res2.ToLower() : res2;
    }

    if (style == 3 || style == 4)
    {
      var words = Number.AsOrdinal(val, style == 4 ? "gen.m" : "nom.m");
      if (style == 3)
        words = words.ToUpperFirst();
      var res34 = string(val).Bind("(" + words + ")", " ").Bind(unit, Number.Join);
      return (keys & 0x01) != 0 ? res34.ToLower() : res34;
    }

    // style 1 (and default): "1-й" feel → number + unit; ordinal words if style==2 already handled
    var res1 = string(val).Bind(unit, Number.Join);
    return (keys & 0x01) != 0 ? res1.ToLower() : res1;
  }

  var res = Number.WithUnit(val, ПРОПИСЬ_ПАРАМ(param), style);
  if ((keys & 0x01) != 0)
    return res.ToLower();
  return res;
}

/** Форматирование числового значения с дополнением параметром "кд"
 *  \param   val     - числовое значение
 *  \param   key     - способ форматирования. см: ПРОПИСЬ
 *  \param   locase  - признак преобразования значения к нижнему регистру
 *  \return  форматированное представление числового значения
 */
string ПРОПИСЬ_КД(int val, int key = 1, bool locase = false)
{
  if (val == 0)
    return (key == 0 ? "" : "<ч> – </ч> ") + "календарных дней";

  return ПРОПИСЬ(val, key == 4 ? "кд.р" : "кд", key, locase ? 0x01 : 0x00);
}

double ОКРУГЛИТЬ_КОП(double val) 
  => Money.RoundKopecks(val);

string ФОРМАТ_СУММЫ(double val, int key = 0, string param = "")
  => Money.FormatAmount(val, key, param == "" ? null : ПРОПИСЬ_ПАРАМ(param));

string ФОРМАТ_РУБ(double val, bool showZero = true)
  => Money.FormatRub(val, showZero);

string ПРОПИСЬ_КОП(int val, int key = 1)
  => Money.InWordsKopecks(val, key, ПРОПИСЬ_ПАРАМ("коп"));

string ПРОПИСЬ_РУБ(double val, int key = 0, string param = "руб")
  => Money.InWords(val, key, param == "" ? null : ПРОПИСЬ_ПАРАМ(param), ПРОПИСЬ_ПАРАМ("коп"));
  