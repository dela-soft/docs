/// Contract / facade for word inflection. Table engine: see WordCaserEngine.
class WordCaserHandler
{
  List _cases = [];          // Declension rows
  List _adjectives = [];     // Adjective word list
  List _exceptionWords = []; // Words skipped by case rules
  List _prepositions = [];   // Prepositions: do not inflect; freeze the rest of the phrase

  // SnpCase(form): low 4 bits = output style; bits 4–7 = which name parts to inflect
  static int SnpStyleMask =>  0000_1111b;  // 0x0F
  static int SnpPartsMask =>  1111_0000b;  // 0xF0
  static int SnpAllParts =>   1111_0000b;
  static int SnpSurname =>    0001_0000b;  // 0x10
  static int SnpName =>       0010_0000b;  // 0x20
  static int SnpPatronymic => 0100_0000b;  // 0x40

  /// Inflect a phrase (department, organization, etc.).
  string Processing(string data, string wCase)
    => (!data)? "" : _doProcessing(NormalData(data), wCase.ToUpper(), "");

  /// Inflect a job title / profession.
  string PostCase(string data, string wCase)
    => (!data)? "" : _doProcessing(NormalData(data), wCase.ToUpper(), "#");

  /// Inflect surname, given name, patronymic.
  string SnpCase(string snp, string wCase, int form = 0)
    => (!snp)? "" : _doSnpCase(NormalData(snp), wCase.ToUpper(), form);

  /// Normalize the input string before inflection.
  string NormalData(string data) => data;

  /// Part of speech: a=adj, n=noun; "-" = preposition / indeclinable.
  string GetWordForm(string word)
  {
    if (IsIndeclinableWord(word))
      return "-";
    if (word.ToLower() in _adjectives)
      return "a";
    return "n";
  }

  /// Whether the word is an exception (general rules).
  bool IsExceptionWord(string word)
    => word.ToLower() in _exceptionWords;

  /// Exceptions for job titles (PostCase).
  bool IsPostExceptionWord(string word)
    => IsExceptionWord(word);

  /// Preposition / freeze marker from `_prepositions`.
  bool IsIndeclinableWord(string word)
    => word.ToLower() in _prepositions;

  /// Locale case letter → row slot (1=first case …); 0 = unknown.
  /// Implemented by the engine / locale — not in the bare handler.
  int CaseSlot(string wCase) => 0;

  // --- engine hooks (WordCaserEngine) ---
  string _doProcessing(string data, string wCase, string formPrefix)
    => throw "WordCaserEngine required";

  string _doSnpCase(string snp, string wCase, int form)
    => throw "WordCaserEngine required";

  string _internalNameCase(int mode, string text, string wCase, bool female)
    => throw "WordCaserEngine required";
}

WordCaserHandler? __wordCaser;
WordCaserHandler WordCaser => __wordCaser ?? throw "Need attach word caser";
