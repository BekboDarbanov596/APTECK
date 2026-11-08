// Генератор демо-данных для приложения «Аптека рядом».
//
// Названия лекарств, МНН и рецептурность — реальные.
// Сети и адреса аптек — из плана исследования, координаты ПРИМЕРНЫЕ.
// Цены и наличие — ДЕМО (заполнены правдоподобно, не реальные остатки).
// Телефоны не указаны: чтобы кнопка «Позвонить» не набирала чужие номера.
// Реальные номера можно вписать из 2ГИС в поле phone.
//
// Запуск:  node tool/generate_demo_data.js
// Результат: assets/demo_data.json (тот же формат потом грузим в Firestore).

const fs = require('fs');
const path = require('path');

// basePrice — ориентир цены в сомах (демо).
const drugs = [
  ['paracetamol-500', 'Парацетамол', '500 мг', 'Таблетки', '10 шт.', 'парацетамол', false, 22, ['paracetamol']],
  ['panadol-500', 'Панадол', '500 мг', 'Таблетки', '12 шт.', 'парацетамол', false, 180, ['panadol']],
  ['ibuprofen-200', 'Ибупрофен', '200 мг', 'Таблетки', '50 шт.', 'ибупрофен', false, 95, ['ibuprofen']],
  ['nurofen-200', 'Нурофен', '200 мг', 'Таблетки', '10 шт.', 'ибупрофен', false, 210, ['nurofen']],
  ['citramon-p', 'Цитрамон П', '', 'Таблетки', '10 шт.', 'ацетилсалициловая кислота + парацетамол + кофеин', false, 25, ['citramon', 'tsitramon']],
  ['no-spa-40', 'Но-шпа', '40 мг', 'Таблетки', '24 шт.', 'дротаверин', false, 260, ['no-spa', 'nospa', 'ношпа']],
  ['drotaverin-40', 'Дротаверин', '40 мг', 'Таблетки', '20 шт.', 'дротаверин', false, 45, ['drotaverin']],
  ['suprastin-25', 'Супрастин', '25 мг', 'Таблетки', '20 шт.', 'хлоропирамин', false, 230, ['suprastin']],
  ['loratadin-10', 'Лоратадин', '10 мг', 'Таблетки', '10 шт.', 'лоратадин', false, 40, ['loratadin', 'loratadine']],
  ['amoxicillin-500', 'Амоксициллин', '500 мг', 'Капсулы', '16 шт.', 'амоксициллин', true, 120, ['amoxicillin']],
  ['azithromycin-250', 'Азитромицин', '250 мг', 'Капсулы', '6 шт.', 'азитромицин', true, 150, ['azithromycin', 'azitromicin']],
  ['augmentin-875', 'Аугментин', '875/125 мг', 'Таблетки', '14 шт.', 'амоксициллин + клавулановая кислота', true, 650, ['augmentin']],
  ['ceftriaxone-1g', 'Цефтриаксон', '1 г', 'Порошок для инъекций', '1 фл.', 'цефтриаксон', true, 60, ['ceftriaxone', 'ceftriakson']],
  ['omeprazol-20', 'Омепразол', '20 мг', 'Капсулы', '30 шт.', 'омепразол', false, 90, ['omeprazol', 'omeprazole']],
  ['smecta-3', 'Смекта', '3 г', 'Порошок', '10 пак.', 'диосмектит', false, 330, ['smecta']],
  ['activated-carbon', 'Активированный уголь', '250 мг', 'Таблетки', '10 шт.', 'активированный уголь', false, 12, ['ugol', 'уголь']],
  ['loperamid-2', 'Лоперамид', '2 мг', 'Капсулы', '20 шт.', 'лоперамид', false, 50, ['loperamid', 'loperamide']],
  ['enalapril-10', 'Эналаприл', '10 мг', 'Таблетки', '20 шт.', 'эналаприл', true, 45, ['enalapril']],
  ['amlodipin-5', 'Амлодипин', '5 мг', 'Таблетки', '30 шт.', 'амлодипин', true, 80, ['amlodipin', 'amlodipine']],
  ['metformin-850', 'Метформин', '850 мг', 'Таблетки', '60 шт.', 'метформин', true, 160, ['metformin']],
  ['aspirin-cardio-100', 'Аспирин Кардио', '100 мг', 'Таблетки', '28 шт.', 'ацетилсалициловая кислота', false, 290, ['aspirin']],
  ['validol-60', 'Валидол', '60 мг', 'Таблетки', '10 шт.', 'ментола раствор в ментилизовалерате', false, 30, ['validol']],
  ['corvalol-25', 'Корвалол', '25 мл', 'Капли', '1 фл.', 'фенобарбитал + этилбромизовалерианат', false, 60, ['corvalol', 'korvalol']],
  ['nazivin-005', 'Називин', '0,05%', 'Спрей назальный', '10 мл', 'оксиметазолин', false, 250, ['nazivin']],
  ['theraflu', 'Терафлю', '', 'Порошок', '10 пак.', 'парацетамол + фенилэфрин + фенирамин', false, 450, ['theraflu', 'teraflu']],
  ['levomekol-40', 'Левомеколь', '40 г', 'Мазь', '1 туба', 'диоксометилтетрагидропиримидин + хлорамфеникол', false, 150, ['levomekol']],
  ['diclofenac-50', 'Диклофенак', '50 мг', 'Таблетки', '20 шт.', 'диклофенак', false, 40, ['diclofenac', 'diklofenak']],
].map(([id, name, strength, form, pack, inn, rx, basePrice, aliases]) => ({
  id, name, strength, form, pack, inn, rx, basePrice, aliases, category: categoryOf(id),
}));

// Разделы каталога — как на сайтах аптек. Это группировка, а не рекомендация к лечению.
function categoryOf(id) {
  const map = {
    'Боль и температура': ['paracetamol-500', 'panadol-500', 'ibuprofen-200', 'nurofen-200', 'citramon-p', 'diclofenac-50', 'no-spa-40', 'drotaverin-40'],
    'Простуда и нос': ['theraflu', 'nazivin-005'],
    'Аллергия': ['suprastin-25', 'loratadin-10'],
    'Желудок и кишечник': ['omeprazol-20', 'smecta-3', 'activated-carbon', 'loperamid-2'],
    'Сердце и давление': ['enalapril-10', 'amlodipin-5', 'aspirin-cardio-100', 'validol-60', 'corvalol-25'],
    'Антибиотики': ['amoxicillin-500', 'azithromycin-250', 'augmentin-875', 'ceftriaxone-1g'],
    'Диабет': ['metformin-850'],
    'Кожа и раны': ['levomekol-40'],
  };
  for (const [category, ids] of Object.entries(map)) if (ids.includes(id)) return category;
  throw new Error(`Нет раздела для ${id}`);
}

// hours: [open, close] в формате HH:MM, или null — круглосуточно.
const pharmacies = [
  ['neman-chuy-125', 'Неман Фарм', 'просп. Чуй, 125', 42.8762, 74.6097, ['08:00', '22:00']],
  ['neman-kievskaya-98', 'Неман Фарм', 'ул. Киевская, 98', 42.8737, 74.5980, ['08:00', '21:00']],
  ['neman-dzhal-23', 'Неман Фарм', 'мкр Джал, 23', 42.8352, 74.5878, ['09:00', '21:00']],
  ['aibolit-bokonbaeva-144', 'Айболит', 'ул. Боконбаева, 144', 42.8688, 74.6002, ['08:00', '22:00']],
  ['aibolit-vostok5-12', 'Айболит', 'мкр Восток-5, 12', 42.8512, 74.6648, ['09:00', '20:00']],
  ['aibolit-manasa-67', 'Айболит', 'просп. Манаса, 67', 42.8652, 74.5882, ['08:00', '23:00']],
  ['farmamir-moskovskaya-134', 'ФармаМир', 'ул. Московская, 134', 42.8706, 74.5992, ['08:00', '22:00']],
  ['farmamir-toktogula-93', 'ФармаМир', 'ул. Токтогула, 93', 42.8722, 74.6052, ['09:00', '21:00']],
  ['farmamir-tunguch-64', 'ФармаМир', 'мкр Тунгуч, 64', 42.8312, 74.6262, ['09:00', '20:00']],
  ['elaman-logvinenko-30', 'Эл Аман', 'ул. Логвиненко, 30/1', 42.8690, 74.5960, ['08:00', '18:00']],
  ['elaman-togoloka-moldo-1', 'Эл Аман', 'ул. Тоголока Молдо, 1', 42.8795, 74.6115, ['08:00', '20:00']],
  ['elaman-fuchika-15', 'Эл Аман', 'ул. Фучика, 15', 42.8875, 74.5870, ['08:00', '18:00']],
  ['farmservis-ahunbaeva-131', 'Фарм-Сервис', 'ул. Ахунбаева, 131', 42.8445, 74.6030, null],
  ['farmservis-beishenalievoi-29', 'Фарм-Сервис', 'ул. Бейшеналиевой, 29', 42.8815, 74.6200, ['08:00', '21:00']],
  ['farvater-ibraimova-115', 'Фарватер', 'ул. Ибраимова, 115', 42.8780, 74.6150, ['09:00', '21:00']],
  ['zdorovie-zhibek-zholu-45', 'Аптека «Здоровье»', 'ул. Жибек Жолу, 45', 42.8870, 74.6000, ['09:00', '19:00']],
].map(([id, chain, address, lat, lng, hours]) => ({
  id, chain, address, lat, lng,
  opensAt: hours ? hours[0] : null,
  closesAt: hours ? hours[1] : null,
  phone: null,
}));

// Сетевой коэффициент цены (демо): госсеть дешевле, одиночная — дороже.
const chainFactor = {
  'Неман Фарм': 1.05, 'Айболит': 1.0, 'ФармаМир': 1.03, 'Эл Аман': 0.92,
  'Фарм-Сервис': 1.04, 'Фарватер': 1.0, 'Аптека «Здоровье»': 1.12,
};

// Детерминированный хеш, чтобы данные не менялись от запуска к запуску.
function hash(str) {
  let h = 2166136261;
  for (const ch of str) { h ^= ch.codePointAt(0); h = Math.imul(h, 16777619); }
  return (h >>> 0) / 4294967295;
}

const offers = [];
for (const p of pharmacies) {
  for (const d of drugs) {
    const r = hash(`${p.id}|${d.id}`);
    if (r > 0.78) continue; // ~22% позиций нет в наличии
    const variation = 0.94 + hash(`${d.id}|${p.id}|price`) * 0.14; // ±7%
    const price = Math.max(5, Math.round(d.basePrice * chainFactor[p.chain] * variation));
    offers.push({ pharmacyId: p.id, drugId: d.id, price });
  }
}

const out = {
  meta: {
    demo: true,
    note: 'Демо-данные: цены и наличие примерные, координаты аптек приблизительные.',
    generatedAt: new Date().toISOString().slice(0, 10),
  },
  drugs: drugs.map(({ basePrice, ...d }) => d),
  pharmacies,
  offers,
};

const target = path.join(__dirname, '..', 'assets', 'demo_data.json');
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, JSON.stringify(out, null, 2) + '\n', 'utf8');
console.log(`OK: ${drugs.length} лекарств, ${pharmacies.length} аптек, ${offers.length} позиций → ${target}`);
