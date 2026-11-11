import '../data/models.dart';
import 'drug_search.dart';
import 'geo.dart';
import 'opening_hours.dart';

/// Язык ответа ассистента. Определяется по сообщению пользователя.
enum AssistantLang { ru, ky, en }

/// Ответ ассистента.
/// [drug] — если спросили про конкретное лекарство (кнопка «Показать на карте»).
/// [suggestions] — препараты из каталога, которые советуем по теме сообщения.
class AssistantReply {
  const AssistantReply(
    this.text, {
    this.drug,
    this.suggestions = const [],
    this.lang = AssistantLang.ru,
  });

  final String text;
  final Drug? drug;
  final List<Drug> suggestions;
  final AssistantLang lang;
}

const assistantGreeting =
    'Здравствуйте! Помогу найти лекарство рядом и сравнить цены, '
    'подскажу, что взять в аптеке при простуде, отравлении или боли.\n'
    'Кыргызча жазсаңыз болот · English is fine too.';

/// Подпись кнопки «Показать на карте» на языке ответа.
String showOnMapLabel(AssistantLang lang) =>
    _t(lang, 'Показать на карте', 'Картадан көрсөтүү', 'Show on map');

String _t(AssistantLang lang, String ru, String ky, String en) =>
    switch (lang) {
      AssistantLang.ru => ru,
      AssistantLang.ky => ky,
      AssistantLang.en => en,
    };

// ---------------------------------------------------------------------------
// Текст: нормализация и язык
// ---------------------------------------------------------------------------

/// Как [normalize], но сохраняет кыргызские буквы ң, ө, ү.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9ңөү]+'), ' ')
    .trim();

const _kyWords = {
  'салам',
  'саламатсызбы',
  'кайда',
  'барбы',
  'жок',
  'дары',
  'дарыкана',
  'дарыканада',
  'керек',
  'канча',
  'турат',
  'арзан',
  'арзаныраак',
  'рахмат',
  'жакшы',
  'мен',
  'менин',
  'мага',
  'эмне',
  'кантип',
  'жедим',
  'жеп',
  'ичтим',
  'ооруйт',
  'ооруп',
  'башым',
  'курсагым',
  'ууландым',
  'ууланып',
  'тамагым',
  'мурунум',
  'жөтөл',
  'суук',
  'тумоо',
  'балам',
  'ысык',
  'кычышат',
  'тиш',
  'белим',
  'жыгылдым',
  'сатып',
  'алсам',
  'болот',
  'кийин',
  'үчүн',
  'жана',
  'эмес',
  'бар',
};

const _enWords = {
  'where',
  'what',
  'how',
  'can',
  'buy',
  'is',
  'the',
  'have',
  'need',
  'my',
  'i',
  'it',
  'hello',
  'hi',
  'hey',
  'thanks',
  'thank',
  'price',
  'cheap',
  'cheapest',
  'pharmacy',
  'medicine',
  'ate',
  'hurts',
  'pain',
  'help',
};

AssistantLang detectLang(String message) {
  final lower = message.toLowerCase();
  if (RegExp('[ңөү]').hasMatch(lower)) return AssistantLang.ky;
  final tokens = _norm(message).split(' ');
  if (tokens.any(_kyWords.contains)) return AssistantLang.ky;
  final latin = RegExp('[a-z]').allMatches(lower).length;
  final cyr = RegExp('[а-я]').allMatches(lower).length;
  if (latin > 0 && cyr == 0) return AssistantLang.en;
  if (latin > cyr && tokens.any(_enWords.contains)) return AssistantLang.en;
  return AssistantLang.ru;
}

// ---------------------------------------------------------------------------
// Темы
// ---------------------------------------------------------------------------

/// Тема разговора: ключевые слова на трёх языках, безрецептурные препараты
/// из каталога и тексты.
///
/// Ключ: «живот» — слово начинается с него, «=жар» — слово целиком,
/// «болит сердце» — фраза.
class _Topic {
  const _Topic({
    required this.id,
    required this.keys,
    required this.intro,
    this.drugIds = const [],
    this.advice,
    this.warning,
    this.emergency = false,
  });

  final String id;
  final List<String> keys;
  final List<String> drugIds;

  /// [ru, ky, en]
  final List<String> intro;
  final List<String>? advice;
  final List<String>? warning;
  final bool emergency;
}

const _topics = <_Topic>[
  _Topic(
    id: 'emergency',
    emergency: true,
    keys: [
      'без сознан',
      'потерял сознан',
      'не дышит',
      'задыха',
      'боль в груди',
      'болит в груди',
      'инфаркт',
      'инсульт',
      'судорог',
      'передозир',
      'суицид',
      'покончить с собой',
      'отек горла',
      'отекло горло',
      'сильное кровотеч',
      'кровь не останавлива',
      'эс учун жогот',
      'дем ала албай',
      'көкүрөгүм ооруп',
      'тырышып',
      'unconscious',
      'not breathing',
      'can t breathe',
      'cannot breathe',
      'chest pain',
      'heart attack',
      'stroke',
      'seizure',
      'overdose',
      'suicid',
      'kill myself',
      'heavy bleeding',
    ],
    intro: [
      'Это может быть опасно для жизни. Срочно звоните 103 (скорая помощь) или 112. '
          'Не ждите и не лечитесь самостоятельно.',
      'Бул өмүргө коркунучтуу болушу мүмкүн. Дароо 103 (тез жардам) же 112ге чалыңыз. '
          'Күтпөңүз жана өз алдынча дарыланбаңыз.',
      'This may be life-threatening. Call 103 (ambulance) or 112 right now. '
          "Don't wait and don't self-treat.",
    ],
  ),
  _Topic(
    id: 'heartburn',
    keys: [
      'изжог',
      'переел',
      'отрыжк',
      'жирн',
      'көкүрөгүм күй',
      'ашказан',
      'heartburn',
      'reflux',
      'acid',
      'overate',
    ],
    drugIds: ['omeprazol-20'],
    intro: [
      'Изжога и тяжесть после жирной или острой еды — частая история. Может помочь:',
      'Майлуу же ачуу тамактан кийин көкүрөк күйүп, ашказан оорлошу көп кездешет. '
          'Жардам бериши мүмкүн:',
      'Heartburn and heaviness after fatty or spicy food are common. This may help:',
    ],
    advice: [
      'Не ложитесь сразу после еды, ешьте меньшими порциями.',
      'Тамактан кийин дароо жатпаңыз, азыраактан жеңиз.',
      "Don't lie down right after eating; eat smaller portions.",
    ],
    warning: [
      'Если изжога почти каждый день или болит за грудиной — к врачу.',
      'Көкүрөк күйүү дээрлик күн сайын болсо же төш ооруса — дарыгерге.',
      'If heartburn happens almost daily or you have chest pain — see a doctor.',
    ],
  ),
  _Topic(
    id: 'hangover',
    keys: [
      'похмел',
      'перепил',
      'алкогол',
      'пиво',
      'пива',
      'водк',
      'вино',
      'вина',
      'коньяк',
      'бухал',
      'выпил',
      'арак',
      'сыра',
      'мас болуп',
      'hangover',
      'alcohol',
      'beer',
      'vodka',
      'wine',
      'drunk',
    ],
    drugIds: ['activated-carbon', 'smecta-3'],
    intro: [
      'После алкоголя организму нужны вода и отдых. В аптеке есть:',
      'Спирт ичимдигинен кийин денеге суу жана эс алуу керек. Дарыканада бар:',
      'After alcohol your body needs water and rest. The pharmacy has:',
    ],
    advice: [
      'Пейте воду. Не принимайте парацетамол вместе с алкоголем — это нагрузка на печень.',
      'Суу ичиңиз. Парацетамолду спирт ичимдиги менен бирге ичпеңиз — боорго оор.',
      "Drink water. Don't take paracetamol with alcohol — it strains the liver.",
    ],
    warning: [
      'Спутанность сознания, многократная рвота, судороги — сразу 103.',
      'Эс-учу чаташса, көп кусса, тырышса — дароо 103.',
      'Confusion, repeated vomiting or seizures — call 103 immediately.',
    ],
  ),
  _Topic(
    id: 'food',
    keys: [
      'самс',
      'шаурм',
      'шаверм',
      'беляш',
      'чебурек',
      'пирожк',
      'плов',
      'манты',
      'лагман',
      'шашлык',
      'бургер',
      'пицц',
      'суши',
      'фастфуд',
      'хот дог',
      'майонез',
      'еда',
      'еды',
      'съел',
      'поел',
      'покушал',
      'отрав',
      'понос',
      'диаре',
      'рвот',
      'тошн',
      'живот',
      'самса',
      'тамак',
      'жедим',
      'жеп',
      'уулан',
      'ич өт',
      'курсагым',
      'кустум',
      'кусуп',
      'жүрөгүм айн',
      'samsa',
      'shawarma',
      'kebab',
      'burger',
      'pizza',
      'sushi',
      'fast food',
      'ate',
      'food',
      'poison',
      'diarrh',
      'vomit',
      'nause',
      'stomach',
      'belly',
      'tummy',
    ],
    drugIds: ['smecta-3', 'activated-carbon', 'loperamid-2'],
    intro: [
      'Самса, шаурма, беляши и другая уличная еда — частая причина пищевого отравления, '
          'особенно если еда долго лежала в тепле. Если отравились, в аптеке есть:',
      'Самса, шаурма, беляш сыяктуу көчө тамагынан ууланып калуу мүмкүн, айрыкча тамак '
          'жылуу жерде көпкө турса. Ууланып калсаңыз, дарыканада булар бар:',
      'Samsa, shawarma, belyashi and other street food often cause food poisoning, '
          'especially if the food sat somewhere warm. If you get poisoned, the pharmacy has:',
    ],
    advice: [
      'Пейте больше воды маленькими глотками, первые часы ешьте лёгкое. '
          'Лоперамид — только при поносе без крови и без температуры.',
      'Сууну аз-аздан көп ичиңиз, алгачкы сааттарда жеңил тамак жеңиз. '
          'Лоперамид — ич кансыз жана ысыксыз өтсө гана.',
      'Drink plenty of water in small sips and eat light for the first hours. '
          'Loperamide only for diarrhea without blood or fever.',
    ],
    warning: [
      'Срочно к врачу или 103: кровь в стуле, температура выше 38,5, рвота не прекращается, '
          'нет мочи, симптомы дольше 2 дней.',
      'Дароо дарыгерге же 103кө: ич кан аралаш болсо, ысык 38,5тен жогору болсо, кусуу '
          'токтобосо, заара жок болсо, 2 күндөн ашык созулса.',
      'See a doctor or call 103 if: blood in stool, fever above 38.5 °C, vomiting that '
          "won't stop, no urine, or symptoms last over 2 days.",
    ],
  ),
  _Topic(
    id: 'allergy',
    keys: [
      'аллерг',
      'чихаю',
      'чихан',
      'зуд',
      'чешет',
      'чешется',
      'сыпь',
      'крапивниц',
      'пыльц',
      'цветен',
      'шерст',
      'кычыш',
      'исиркек',
      'чүчкүр',
      'allerg',
      'sneez',
      'itch',
      'rash',
      'hives',
      'pollen',
      'hay fever',
    ],
    drugIds: ['loratadin-10', 'suprastin-25'],
    intro: [
      'При аллергии (чихание, зуд, сыпь) обычно помогают антигистаминные:',
      'Аллергияда (чүчкүрүү, кычышуу, исиркек) адатта антигистаминдик дарылар жардам берет:',
      'For allergies (sneezing, itching, rash) antihistamines usually help:',
    ],
    advice: [
      'Супрастин может вызывать сонливость — не садитесь за руль. '
          'Лоратадин вызывает сонливость реже.',
      'Супрастин уйку келтириши мүмкүн — рулга отурбаңыз. Лоратадин уйкуну азыраак келтирет.',
      "Suprastin can make you drowsy — don't drive. Loratadine causes drowsiness less often.",
    ],
    warning: [
      'Отёк лица, губ или горла, трудно дышать — сразу 103.',
      'Бет, эрин же тамак шишип, дем алуу кыйындаса — дароо 103.',
      'Swelling of the face, lips or throat, or trouble breathing — call 103 immediately.',
    ],
  ),
  _Topic(
    id: 'cold',
    keys: [
      'простуд',
      'простыл',
      'насморк',
      'сопл',
      'заложен',
      'грипп',
      'орви',
      'кашел',
      'кашл',
      'горло',
      'горла',
      'замерз',
      'холод',
      'мороз',
      'снег',
      'дожд',
      '=нос',
      'тумоо',
      'мурун',
      'жөтөл',
      'тамагым',
      'суук',
      'үшүп',
      'cold',
      'flu',
      'runny',
      'nose',
      'cough',
      'throat',
      'freez',
      'snow',
      'rain',
    ],
    drugIds: ['theraflu', 'nazivin-005', 'paracetamol-500'],
    intro: [
      'При простуде, насморке и гриппе в аптеке есть:',
      'Суук тийгенде, мурун бүтүп, тумоо болгондо дарыканада бар:',
      'For a cold, runny nose or flu the pharmacy has:',
    ],
    advice: [
      'Пейте тёплое, отдыхайте. Капли для носа — не дольше 5–7 дней подряд. '
          'Антибиотики при простуде не помогают и продаются по рецепту.',
      'Жылуу суюктук ичип, эс алыңыз. Мурунга тамчы — 5–7 күндөн ашык эмес. '
          'Антибиотиктер суук тийгенге жардам бербейт жана рецепт менен сатылат.',
      'Drink warm fluids and rest. Nasal drops for no more than 5–7 days in a row. '
          "Antibiotics don't help a cold and need a prescription.",
    ],
    warning: [
      'К врачу: трудно дышать, температура дольше 3 дней, боль в груди, '
          'сильная боль в горле или ухе.',
      'Дарыгерге: дем алуу кыйын болсо, ысык 3 күндөн ашык болсо, көкүрөк ооруса, '
          'тамак же кулак катуу ооруса.',
      'See a doctor: trouble breathing, fever over 3 days, chest pain, '
          'severe throat or ear pain.',
    ],
  ),
  _Topic(
    id: 'heat',
    keys: [
      '=жара',
      '=жаре',
      '=жару',
      'жарк',
      'солнц',
      'перегрел',
      'загар',
      'пляж',
      'аптап',
      'күн өт',
      'sun',
      'heat',
      'beach',
    ],
    drugIds: ['paracetamol-500'],
    intro: [
      'Жара и солнце могут вызвать перегрев и головную боль. Главное — вода и тень. '
          'От головной боли:',
      'Аптап жана күн денени ысытып, баш оорутушу мүмкүн. Эң негизгиси — суу жана көлөкө. '
          'Баш ооруса:',
      'Heat and sun can cause overheating and headaches. Water and shade come first. '
          'For a headache:',
    ],
    advice: [
      'Пейте воду, избегайте солнца с 12 до 16 часов.',
      'Суу ичиңиз, саат 12ден 16га чейин күнгө чыкпаңыз.',
      'Drink water and avoid the sun from 12:00 to 16:00.',
    ],
    warning: [
      'Спутанность сознания, температура тела выше 39, кожа сухая и горячая — это тепловой '
          'удар, звоните 103.',
      'Эс-учу чаташса, дене ысыгы 39дан жогору болсо, тери кургак жана ысык болсо — бул '
          'күн өтүү, 103кө чалыңыз.',
      'Confusion, body temperature above 39 °C, hot dry skin — that is heatstroke, call 103.',
    ],
  ),
  _Topic(
    id: 'spasm',
    keys: [
      'спазм',
      'месячн',
      'менструа',
      'колик',
      'колет',
      'айыз',
      'cramp',
      'period',
      'spasm',
      'menstrua',
    ],
    drugIds: ['drotaverin-40', 'no-spa-40', 'ibuprofen-200'],
    intro: [
      'При спазмах и болезненных месячных используют спазмолитики и обезболивающие:',
      'Спазмда жана айыз оорутканда спазмды басуучу жана оорутпоочу дарылар колдонулат:',
      'For cramps and painful periods, antispasmodics and pain relievers are used:',
    ],
    advice: [
      'Дротаверин — то же вещество, что и в Но-шпе, обычно дешевле.',
      'Дротаверин — Но-шпадагы эле зат, адатта арзаныраак.',
      'Drotaverine is the same substance as No-Spa and is usually cheaper.',
    ],
    warning: [
      'Резкая боль в животе, особенно справа внизу, температура, рвота — к врачу или 103.',
      'Курсак капыстан катуу ооруса, айрыкча оң жак ылдыйы, ысык, кусуу болсо — '
          'дарыгерге же 103.',
      'Sudden sharp belly pain (especially lower right), fever or vomiting — '
          'see a doctor or call 103.',
    ],
  ),
  _Topic(
    id: 'muscle',
    keys: [
      'спин',
      'поясниц',
      'мышц',
      'сустав',
      'колен',
      'ушиб',
      'ударил',
      'растяж',
      'спорт',
      'трениров',
      'футбол',
      'спортзал',
      'упал',
      'белим',
      'булчуң',
      'муун',
      'жыгыл',
      'урун',
      'back',
      'muscle',
      'joint',
      'knee',
      'bruise',
      'sprain',
      'gym',
      'workout',
      'football',
      'sport',
      'fell',
    ],
    drugIds: ['ibuprofen-200', 'diclofenac-50'],
    intro: [
      'При боли в спине, мышцах, суставах и после ушибов используют противовоспалительные:',
      'Бел, булчуң, муун ооруганда жана урунгандан кийин сезгенүүгө каршы дарылар колдонулат:',
      'For back, muscle or joint pain and bruises, anti-inflammatories are used:',
    ],
    advice: [
      'На ушиб в первые сутки — холод. Не принимайте два противовоспалительных сразу '
          '(диклофенак + ибупрофен). Если болит желудок — осторожно.',
      'Урунган жерге биринчи суткада муздак басыңыз. Эки сезгенүүгө каршы дарыны бирге '
          'ичпеңиз (диклофенак + ибупрофен). Ашказаныңыз ооруса — абайлаңыз.',
      "Apply cold to a bruise during the first day. Don't take two anti-inflammatories "
          'together (diclofenac + ibuprofen). Be careful if you have stomach problems.',
    ],
    warning: [
      'Сильная боль после падения, отёк, не можете опереться на ногу — к травматологу.',
      'Жыгылгандан кийин катуу ооруса, шишисе, бутка тура албасаңыз — травматологго.',
      "Severe pain after a fall, swelling, or you can't put weight on your leg — "
          'see a trauma doctor.',
    ],
  ),
  _Topic(
    id: 'wound',
    keys: [
      'порез',
      'порезал',
      '=рана',
      '=раны',
      '=рану',
      'ранк',
      'царап',
      'ссадин',
      'ожог',
      'обжег',
      'нарыв',
      'прыщ',
      'гноя',
      'гной',
      'жаракат',
      'кесип',
      'кесилди',
      'сыдырыл',
      'ириң',
      'cut',
      'wound',
      'scratch',
      'burn',
      'scrape',
      'pimple',
    ],
    drugIds: ['levomekol-40'],
    intro: [
      'Для небольших порезов, ссадин и гнойничков есть мазь:',
      'Майда кесилген, сыдырылган жерге жана ириңдүү бүдүрчөккө май бар:',
      'For small cuts, scrapes and pimples there is an ointment:',
    ],
    advice: [
      'Сначала промойте рану чистой водой. При ожоге — прохладная вода 10–15 минут, '
          'на свежий ожог мазь не наносите.',
      'Адегенде жараны таза суу менен жууңуз. Күйүп калса — 10–15 мүнөт салкын суу, '
          'жаңы күйүккө май сүртпөңүз.',
      "Rinse the wound with clean water first. For a burn — cool water for 10–15 minutes; "
          "don't put ointment on a fresh burn.",
    ],
    warning: [
      'Глубокая рана, кровь не останавливается, укус животного, большой ожог — к врачу.',
      'Жара терең болсо, кан токтобосо, жаныбар тиштесе, чоң күйүк болсо — дарыгерге.',
      "Deep wound, bleeding that won't stop, animal bite, or a large burn — see a doctor.",
    ],
  ),
  _Topic(
    id: 'heart',
    keys: [
      'давлен',
      'сердц',
      'сердеч',
      'пульс',
      'гипертон',
      'тахикард',
      'кан басым',
      'жүрөк',
      'жүрөгүм',
      'blood pressure',
      'pressure',
      'heart',
      'pulse',
      'hypertension',
    ],
    intro: [
      'Лекарства от давления и для сердца в нашем каталоге (Эналаприл, Амлодипин) '
          'отпускаются по рецепту — подбирает их врач. Если рецепт есть, напишите название — '
          'покажу, где купить.',
      'Каталогдогу кан басымга жана жүрөккө каршы дарылар (Эналаприл, Амлодипин) рецепт '
          'менен берилет — аларды дарыгер тандайт. Рецептиңиз болсо, атын жазыңыз — '
          'кайдан сатып алууну көрсөтөм.',
      'Blood pressure and heart medicines in our catalog (Enalapril, Amlodipine) need a '
          "prescription — a doctor chooses them. If you have one, type the name and I'll "
          'show where to buy it.',
    ],
    warning: [
      'Боль в груди, онемение руки или лица, нарушение речи — сразу звоните 103.',
      'Көкүрөк ооруса, кол же бет уюп калса, сүйлөө бузулса — дароо 103кө чалыңыз.',
      'Chest pain, numbness in an arm or face, or slurred speech — call 103 immediately.',
    ],
  ),
  _Topic(
    id: 'pain',
    keys: [
      'голов',
      'температур',
      '=жар',
      'знобит',
      'мигрен',
      'зуб',
      'болит',
      'боль',
      'ломит',
      'башым',
      'баш оор',
      'ысык',
      'тиш',
      'ооруйт',
      'ооруп',
      'headache',
      'head',
      'fever',
      'temperature',
      'migraine',
      'tooth',
      'pain',
      'ache',
      'hurt',
    ],
    drugIds: ['paracetamol-500', 'ibuprofen-200', 'citramon-p'],
    intro: [
      'При головной боли и температуре обычно используют обезболивающие и жаропонижающие:',
      'Баш ооруганда жана ысык көтөрүлгөндө адатта оорутпоочу жана ысыкты түшүрүүчү '
          'дарылар колдонулат:',
      'For headache and fever, pain relievers and fever reducers are usually used:',
    ],
    advice: [
      'Не совмещайте несколько препаратов с парацетамолом (он есть и в Цитрамоне, и в Терафлю). '
          'При зубной боли — к стоматологу.',
      'Парацетамол бар дарыларды бирге ичпеңиз (ал Цитрамондо да, Терафлюда да бар). '
          'Тиш ооруса — тиш дарыгерине.',
      "Don't combine several paracetamol products (Citramon and Theraflu contain it too). "
          'For toothache — see a dentist.',
    ],
    warning: [
      'К врачу: температура выше 39 или дольше 3 дней, очень сильная внезапная головная '
          'боль, напряжённая шея, сыпь.',
      'Дарыгерге: ысык 39дан жогору же 3 күндөн ашык болсо, баш капыстан катуу ооруса, '
          'моюн катып калса, исиркек чыкса.',
      'See a doctor: fever above 39 °C or longer than 3 days, sudden severe headache, '
          'stiff neck, rash.',
    ],
  ),
  _Topic(
    id: 'prescription',
    keys: [
      'антибиот',
      'диабет',
      'сахар в крови',
      'уколы',
      'антибиотик',
      'кант диабет',
      'antibiotic',
      'diabet',
      'insulin',
    ],
    intro: [
      'Антибиотики и лекарства от диабета продаются только по рецепту — их назначает врач, '
          'подбирать самому опасно. Если рецепт есть, напишите название — покажу, где дешевле.',
      'Антибиотиктер жана диабет дарылары рецепт менен гана сатылат — аларды дарыгер '
          'жазат, өз алдынча тандоо коркунучтуу. Рецепт болсо, атын жазыңыз — кайда арзан '
          'экенин көрсөтөм.',
      'Antibiotics and diabetes medicines are prescription-only — a doctor prescribes them, '
          "choosing them yourself is dangerous. If you have a prescription, type the name and "
          "I'll show where it's cheapest.",
    ],
  ),
  _Topic(
    id: 'stress',
    keys: [
      'стресс',
      'нерв',
      'бессонниц',
      'не могу уснуть',
      'не сплю',
      'тревог',
      'экзамен',
      'депресс',
      'уйку',
      'уктай албай',
      'тынчсыз',
      'stress',
      'anxiety',
      'anxious',
      'insomnia',
      'can t sleep',
      'exam',
      'depress',
    ],
    intro: [
      'Стресс и плохой сон лучше обсудить с врачом: успокоительные из нашего каталога '
          '(например, Корвалол) содержат фенобарбитал и не подходят для самолечения. '
          'Помогают режим сна, прогулки и меньше кофе вечером.',
      'Стресс жана начар уйку жөнүндө дарыгер менен сүйлөшкөн оң: биздин каталогдогу '
          'тынчтандыруучу дарыларда (мисалы, Корвалол) фенобарбитал бар, өз алдынча ичүүгө '
          'туура келбейт. Уйку тартиби, сейилдөө жана кечинде кофени азайтуу жардам берет.',
      'Stress and poor sleep are best discussed with a doctor: the sedatives in our catalog '
          "(e.g. Corvalol) contain phenobarbital and aren't for self-treatment. A sleep "
          'routine, walks and less coffee in the evening help.',
    ],
    warning: [
      'Если очень тяжело и появляются мысли причинить себе вред — позвоните 103 '
          'или скажите близким прямо сейчас.',
      'Өтө оор болуп, өзүңүзгө зыян келтирүү ою келсе — 103кө чалыңыз же жакындарыңызга '
          'азыр эле айтыңыз.',
      'If it feels unbearable or you think about harming yourself — call 103 '
          'or tell someone close to you right now.',
    ],
  ),
];

/// Дети, беременность, кормление — дозы другие.
const _specialGroupKeys = [
  'ребен',
  'ребён',
  'детск',
  'дет',
  'малыш',
  'сын',
  'дочь',
  'дочк',
  'беремен',
  'кормлю грудью',
  'бала',
  'балам',
  'наристе',
  'кош бойлуу',
  'эмизем',
  'child',
  'kid',
  'baby',
  'son',
  'daughter',
  'pregnan',
  'breastfeed',
];

const _greetingKeys = [
  '=привет',
  '=прив',
  '=приветик',
  '=здрасте',
  'здравств',
  'добрый день',
  'добрый вечер',
  'доброе утро',
  '=салам',
  'саламатсыз',
  'кандайсыз',
  '=hello',
  '=hi',
  '=hey',
  'good morning',
  'good evening',
];

/// Светская беседа: «как дела», «кто ты».
const _smallTalkKeys = [
  'как дела',
  'как ты',
  'как жизнь',
  'как поживаешь',
  'как настроение',
  'что делаешь',
  'кто ты',
  'ты кто',
  'что ты умеешь',
  'кандайсыз',
  'кандайсың',
  'иштер кандай',
  'эмне кыласың',
  'сен кимсиң',
  'how are you',
  'how r u',
  'what s up',
  'whats up',
  'who are you',
  'what can you do',
];

const _thanksKeys = ['спасибо', 'благодар', 'рахмат', 'thank', '=thx'];

/// Слова, по которым понятно, что спрашивают про конкретное лекарство.
const _drugIntentKeys = [
  'где',
  'купить',
  'аналог',
  'цена',
  'стоит',
  'лекарств',
  'таблетк',
  'препарат',
  'налич',
  'кайда',
  'дары',
  'канча',
  'сатып',
  'where',
  'buy',
  'price',
  'cost',
  'analog',
  'medicine',
  'pill',
  'tablet',
  'drug',
];

bool _hasKey(String text, List<String> tokens, String key) {
  if (key.startsWith('=')) return tokens.contains(key.substring(1));
  if (key.contains(' ')) return ' $text '.contains(' $key');
  return tokens.any((t) => t.startsWith(key));
}

bool _hasAny(String text, List<String> tokens, List<String> keys) =>
    keys.any((k) => _hasKey(text, tokens, k));

/// Слово — часть какой-то темы (его не надо искать как название лекарства).
bool _isTopicWord(String token) {
  for (final topic in _topics) {
    for (final k in topic.keys) {
      if (k.startsWith('=')
          ? token == k.substring(1)
          : (!k.contains(' ') && token.startsWith(k))) {
        return true;
      }
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Ответ
// ---------------------------------------------------------------------------

/// Слова, которые не являются названием лекарства (ru / ky / en).
const _stopWords = {
  'где',
  'есть',
  'купить',
  'найти',
  'найди',
  'нужен',
  'нужна',
  'нужно',
  'мне',
  'а',
  'и',
  'в',
  'на',
  'по',
  'для',
  'аптека',
  'аптеке',
  'аптеки',
  'рядом',
  'ближайшая',
  'ближайшую',
  'дешевле',
  'дешевый',
  'дешевая',
  'аналог',
  'аналоги',
  'аналогов',
  'цена',
  'цену',
  'сколько',
  'стоит',
  'наличие',
  'наличии',
  'ли',
  'какие',
  'какой',
  'подскажи',
  'подскажите',
  'пожалуйста',
  'можно',
  'хочу',
  'лекарство',
  'таблетки',
  'препарат',
  'у',
  'вас',
  'есть?',
  'привет',
  'здравствуйте',
  'я',
  'что',
  'выпить',
  'принять',
  'от',
  'после',
  'чем',
  'это',
  'мой',
  'моя',
  'меня',
  'кайда',
  'бар',
  'барбы',
  'керек',
  'канча',
  'турат',
  'арзан',
  'аналогу',
  'аналогдору',
  'дарыкана',
  'дарыканада',
  'жакын',
  'мага',
  'сатып',
  'алам',
  'алсам',
  'болот',
  'дары',
  'салам',
  'рахмат',
  'мен',
  'менин',
  'where',
  'is',
  'can',
  'i',
  'buy',
  'find',
  'need',
  'the',
  'a',
  'an',
  'do',
  'you',
  'have',
  'price',
  'cheap',
  'cheaper',
  'cheapest',
  'analog',
  'analogs',
  'pharmacy',
  'near',
  'me',
  'how',
  'much',
  'of',
  'for',
  'to',
  'get',
  'please',
  'what',
  'my',
  'some',
  'any',
};

/// Ответ на сообщение пользователя. Говорит на русском, кыргызском и английском,
/// отвечает только на аптечные темы и советует безрецептурные препараты из каталога.
AssistantReply assistantReply({
  required String message,
  required Catalog catalog,
  required double userLat,
  required double userLng,
  required DateTime now,
}) {
  final text = _norm(message);
  if (text.isEmpty) return const AssistantReply(assistantGreeting);

  final lang = detectLang(message);
  final tokens = text.split(' ');
  final ctx = _Ctx(catalog, userLat, userLng, now, lang);

  final topic = _topics.cast<_Topic?>().firstWhere(
    (t) => _hasAny(text, tokens, t!.keys),
    orElse: () => null,
  );

  // Опасные симптомы — раньше всего остального.
  if (topic != null && topic.emergency) {
    return AssistantReply(_pick(lang, topic.intro), lang: lang);
  }

  // Конкретное лекарство по названию.
  final words = tokens
      .where((w) => !_stopWords.contains(w) && !_isTopicWord(w))
      .toList();
  final drug = _findDrug(catalog, words);
  // При распознанной теме нечёткое совпадение («калды» ≈ «кардио») не считаем.
  if (drug != null && (topic == null || _namedExplicitly(drug, words))) {
    return _drugReply(ctx, drug);
  }

  if (topic != null) {
    return _topicReply(
      ctx,
      topic,
      special: _hasAny(text, tokens, _specialGroupKeys),
    );
  }

  if (_hasAny(text, tokens, _smallTalkKeys)) {
    return AssistantReply(
      _t(
        lang,
        'Спасибо, у меня всё хорошо! Я помощник по аптекам: подскажу, где есть лекарство '
            'и где дешевле, и что обычно берут в аптеке при простуде, отравлении, аллергии '
            'или боли. Как вы себя чувствуете?',
        'Рахмат, жакшы! Мен дарыкана боюнча жардамчымын: дары кайда бар, кайда арзан '
            'экенин жана суук тийгенде, ууланганда, аллергияда же ооруганда дарыканадан '
            'адатта эмне алышарын айтып берем. Өзүңүзду кандай сезип жатасыз?',
        "Thanks, I'm good! I'm a pharmacy helper: I can tell you where a medicine is in "
            'stock, where it is cheaper, and what people usually buy for a cold, food '
            'poisoning, allergies or pain. How are you feeling?',
      ),
      lang: lang,
    );
  }
  if (_hasAny(text, tokens, _thanksKeys)) {
    return AssistantReply(
      _t(
        lang,
        'Пожалуйста! Будьте здоровы.',
        'Эч нерсе эмес! Ден соолугуңуз чың болсун.',
        "You're welcome! Stay healthy.",
      ),
      lang: lang,
    );
  }
  if (_hasAny(text, tokens, _greetingKeys)) {
    return AssistantReply(
      _t(
        lang,
        'Здравствуйте! Чем помочь? Напишите название лекарства или что вас беспокоит.',
        'Саламатсызбы! Эмне жардам керек? Дарынын атын же эмне тынчсыздандырып жатканын '
            'жазыңыз.',
        "Hello! How can I help? Type a medicine name or what's bothering you.",
      ),
      lang: lang,
    );
  }

  // Похоже на поиск лекарства, но такого нет.
  if (_hasAny(text, tokens, _drugIntentKeys) || tokens.length == 1) {
    return AssistantReply(
      _t(
        lang,
        'Такого лекарства нет в каталоге. Проверьте название или напишите действующее '
            'вещество, например «ибупрофен». Ещё можно описать, что беспокоит: '
            '«болит голова», «насморк», «съел что-то не то».',
        'Мындай дары каталогдо жок. Атын текшериңиз же таасир берүүчү затты жазыңыз, '
            'мисалы «ибупрофен». Же эмне тынчсыздандырып жатканын жазыңыз: '
            '«башым ооруйт», «мурунум бүтүп калды».',
        "That medicine isn't in the catalog. Check the spelling or type the active "
            'ingredient, e.g. "ibuprofen". You can also describe what bothers you: '
            '"headache", "runny nose", "ate something bad".',
      ),
      lang: lang,
    );
  }

  // Не по теме аптеки.
  return AssistantReply(
    _t(
      lang,
      'Я отвечаю только на аптечные темы: лекарства, цены, наличие, аналоги и что купить '
          'в аптеке при частых проблемах (простуда, отравление, аллергия, боль).\n'
          'Например: «Где есть Нурофен?» или «Съел самсу, болит живот».',
      'Мен дарыкана темалары боюнча гана жооп берем: дарылар, баалар, кайда бар экени, '
          'аналогдор жана көп кездешкен көйгөйлөрдө (суук тийүү, уулануу, аллергия, оору) '
          'дарыканадан эмне алуу керек.\n'
          'Мисалы: «Нурофен кайда бар?» же «Самса жедим, курсагым ооруйт».',
      'I only answer pharmacy questions: medicines, prices, availability, analogs and what '
          'to buy for common problems (cold, food poisoning, allergy, pain).\n'
          'For example: "Where can I buy Nurofen?" or "I ate samsa and my stomach hurts".',
    ),
    lang: lang,
  );
}

String _pick(AssistantLang lang, List<String> v) => v[lang.index];

class _Ctx {
  _Ctx(this.catalog, this.lat, this.lng, this.now, this.lang);

  final Catalog catalog;
  final double lat;
  final double lng;
  final DateTime now;
  final AssistantLang lang;

  double dist(Offer o) {
    final p = catalog.pharmacy(o.pharmacyId)!;
    return distanceMeters(lat, lng, p.lat, p.lng);
  }

  String distance(Offer o) {
    final s = formatDistance(dist(o));
    if (lang != AssistantLang.en) return s;
    return s
        .replaceAll(',', '.')
        .replaceAll(' км', ' km')
        .replaceAll(' м', ' m');
  }

  String som(int price) =>
      lang == AssistantLang.en ? '$price som' : '$price сом';

  /// Открытые сейчас предложения, а если таких нет — все.
  (List<Offer> pool, int openCount) offers(Drug d) {
    final all = catalog.offersForDrug(d.id);
    final open = all
        .where((o) => isOpenAt(catalog.pharmacy(o.pharmacyId)!, now))
        .toList();
    return (open.isNotEmpty ? open : all, open.length);
  }

  String name(Drug d) {
    if (lang != AssistantLang.en) return d.title;
    if (d.id == 'activated-carbon') return 'Activated charcoal 250 mg';
    final latin = d.aliases.firstWhere(
      (a) => RegExp(r'^[a-z][a-z\-]*$').hasMatch(a),
      orElse: () => '',
    );
    if (latin.isEmpty) return d.title;
    final n = latin[0].toUpperCase() + latin.substring(1);
    final strength = d.strength
        .replaceAll('мг', 'mg')
        .replaceAll('мл', 'ml')
        .replaceAll(RegExp(r'(?<=\d) г$'), ' g')
        .replaceAll(',', '.');
    return strength.isEmpty ? n : '$n $strength';
  }
}

AssistantReply _drugReply(_Ctx c, Drug drug) {
  final lang = c.lang;
  final catalog = c.catalog;
  final buf = StringBuffer(
    lang == AssistantLang.en
        ? '${c.name(drug)}.\n'
        : '${drug.title} (${drug.subtitle.toLowerCase()}).\n',
  );
  if (drug.rx) {
    buf.writeln(
      _t(
        lang,
        'Отпускается только по рецепту врача.',
        'Дарыгердин рецепти менен гана берилет.',
        'Prescription only.',
      ),
    );
  }

  final all = catalog.offersForDrug(drug.id);
  if (all.isEmpty) {
    buf.writeln(
      _t(
        lang,
        'Сейчас нет ни в одной аптеке.',
        'Азыр эч бир дарыканада жок.',
        'Not available in any pharmacy right now.',
      ),
    );
  } else {
    final (pool, openCount) = c.offers(drug);
    final nearest = pool.reduce((a, b) => c.dist(a) <= c.dist(b) ? a : b);
    final cheapest = pool.reduce((a, b) => a.price <= b.price ? a : b);

    String describe(Offer o) {
      final p = catalog.pharmacy(o.pharmacyId)!;
      return '${p.chain}, ${p.address} — ${c.som(o.price)}, ${c.distance(o)}';
    }

    final n = all.length;
    buf.writeln(
      openCount == 0
          ? _t(
              lang,
              'Есть в $n аптеках (сейчас все закрыты).',
              '$n дарыканада бар (азыр баары жабык).',
              'Available in $n pharmacies (all closed now).',
            )
          : _t(
              lang,
              'Есть в $n аптеках, открыто сейчас: $openCount.',
              '$n дарыканада бар, азыр ачык: $openCount.',
              'Available in $n pharmacies, open now: $openCount.',
            ),
    );
    buf.writeln(
      '${_t(lang, 'Ближайшая', 'Эң жакыны', 'Nearest')}: ${describe(nearest)}.',
    );
    if (cheapest.pharmacyId != nearest.pharmacyId) {
      buf.writeln(
        '${_t(lang, 'Дешевле всего', 'Эң арзаны', 'Cheapest')}: ${describe(cheapest)}.',
      );
    }
  }

  final analogs = catalog.analogs(drug);
  if (analogs.isNotEmpty) {
    buf.write(
      _t(
        lang,
        'Аналоги с тем же действующим веществом (${drug.inn}): ',
        'Ошол эле таасир берүүчү заты бар аналогдор (${drug.inn}): ',
        'Analogs with the same active ingredient: ',
      ),
    );
    buf.write(
      analogs
          .map((a) {
            final min = catalog.minPrice(a.id);
            if (min == null)
              return '${c.name(a)} — ${_t(lang, 'нет в наличии', 'жок', 'out of stock')}';
            return '${c.name(a)} — ${_t(lang, 'от ${c.som(min)}', '${c.som(min)}дан баштап', 'from ${c.som(min)}')}';
          })
          .join('; '),
    );
    buf.writeln('.');
    buf.write(
      _t(
        lang,
        'Перед заменой посоветуйтесь с врачом или фармацевтом.',
        'Алмаштыруудан мурун дарыгер же фармацевт менен кеңешиңиз.',
        'Check with a doctor or pharmacist before switching.',
      ),
    );
  }

  return AssistantReply(buf.toString().trim(), drug: drug, lang: lang);
}

AssistantReply _topicReply(_Ctx c, _Topic topic, {required bool special}) {
  final lang = c.lang;
  final buf = StringBuffer(_pick(lang, topic.intro));
  final suggested = <Drug>[];

  for (final id in topic.drugIds) {
    final d = c.catalog.drug(id);
    if (d == null || d.rx) continue; // рецептурное по симптомам не советуем
    suggested.add(d);
    final (pool, _) = c.offers(d);
    buf.write('\n• ${c.name(d)}');
    if (pool.isEmpty) {
      buf.write(
        ' — ${_t(lang, 'сейчас нет в наличии', 'азыр жок', 'out of stock now')}',
      );
      continue;
    }
    final cheapest = pool.map((o) => o.price).reduce((a, b) => a < b ? a : b);
    final nearest = pool.reduce((a, b) => c.dist(a) <= c.dist(b) ? a : b);
    final p = c.catalog.pharmacy(nearest.pharmacyId)!;
    buf.write(
      _t(
        lang,
        ' — от ${c.som(cheapest)}, ближе всего: ${p.chain} (${c.distance(nearest)})',
        ' — ${c.som(cheapest)}дан баштап, эң жакыны: ${p.chain} (${c.distance(nearest)})',
        ' — from ${c.som(cheapest)}, nearest: ${p.chain} (${c.distance(nearest)})',
      ),
    );
  }

  if (topic.advice != null) buf.write('\n\n${_pick(lang, topic.advice!)}');
  if (special) {
    buf.write(
      '\n\n${_t(lang, 'Для детей, беременных и кормящих дозы и препараты другие — сначала уточните '
          'у врача или фармацевта.', 'Балдар, кош бойлуу жана эмизген аялдар үчүн дозалар жана дарылар башкача — '
          'адегенде дарыгерден же фармацевттен сураңыз.', 'For children, pregnant or breastfeeding women doses and medicines differ — '
          'check with a doctor or pharmacist first.')}',
    );
  }
  if (topic.warning != null) buf.write('\n\n⚠️ ${_pick(lang, topic.warning!)}');
  if (suggested.isNotEmpty) {
    buf.write(
      '\n\n${_t(lang, 'Принимайте строго по инструкции. Это справка, а не назначение врача.', 'Нускамага так ылайык ичиңиз. Бул маалымат гана, дарыгердин дайындамасы эмес.', "Follow the package instructions. This is general information, not a doctor's "
          'prescription.')}',
    );
  }

  return AssistantReply(buf.toString(), suggestions: suggested, lang: lang);
}

/// Название препарата действительно есть в сообщении (с учётом окончаний).
bool _namedExplicitly(Drug drug, List<String> words) {
  final names = normalize(
    [drug.name, drug.inn, ...drug.aliases].join(' '),
  ).split(' ').where((t) => t.length >= 4).toList();
  final joined = [
    ...words,
    for (var i = 0; i + 1 < words.length; i++) words[i] + words[i + 1],
  ];
  return joined.any((w) {
    if (w.length < 4) return false;
    final stem = w.substring(0, w.length > 5 ? 5 : w.length - 1);
    return names.any((t) => t.startsWith(stem));
  });
}

Drug? _findDrug(Catalog catalog, List<String> words) {
  words = words.where((w) => !RegExp('[ңөү]').hasMatch(w)).toList();
  if (words.isEmpty) return null;
  // Сначала вся фраза целиком, потом каждое слово по отдельности.
  final whole = searchDrugs(catalog.drugs, words.join(' '), limit: 1);
  if (whole.isNotEmpty) return whole.first;
  // «но шпы» — название было через дефис, normalize его разделил.
  for (var i = 0; i + 1 < words.length; i++) {
    final joined = searchDrugs(
      catalog.drugs,
      words[i] + words[i + 1],
      limit: 1,
    );
    if (joined.isNotEmpty) return joined.first;
  }
  for (final w in words) {
    if (w.length < 3) continue;
    final found = searchDrugs(catalog.drugs, w, limit: 1);
    if (found.isNotEmpty) return found.first;
  }
  return null;
}
