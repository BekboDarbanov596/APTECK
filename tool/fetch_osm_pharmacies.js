// Скачивает реальные аптеки Бишкека из OpenStreetMap (через геокодер Nominatim)
// и сохраняет снимок в assets/osm_pharmacies.json. Генератор демо-данных
// (tool/generate_demo_data.js) берёт оттуда точные координаты и адреса.
//
// Данные © участники OpenStreetMap, лицензия ODbL.
// Правила Nominatim: не чаще 1 запроса в секунду, свой User-Agent.
//
// Запуск:  node tool/fetch_osm_pharmacies.js
//          node tool/generate_demo_data.js

const fs = require('fs');
const path = require('path');

const UA = 'apteka-ryadom/0.1 (student project, Bishkek pharmacy finder)';
const VIEWBOX = '74.45,42.95,74.75,42.78'; // Бишкек
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function nominatim(params) {
  const url = new URL('https://nominatim.openstreetmap.org/search');
  for (const [k, v] of Object.entries({
    format: 'jsonv2',
    addressdetails: '1',
    extratags: '1',
    'accept-language': 'ru',
    countrycodes: 'kg',
    ...params,
  })) url.searchParams.set(k, v);
  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`Nominatim ${res.status}`);
  await sleep(1100);
  return res.json();
}

// Сети и как их ищем.
const chains = [
  ['Неман Фарм', 'Неман'],
  ['Айболит', 'Айболит'],
  ['ФармаМир', 'Фармамир'],
  ['Фарм-Сервис', 'Фарм-Сервис'],
  ['Фарватер', 'Фарватер'],
  ['Эл Аман', 'Эл Аман'],
];

// Адреса из плана исследования (их проверяли на месте) — геокодируем точно.
const knownAddresses = {
  'neman-chuy-125': 'проспект Чуй 125',
  'farmamir-moskovskaya-134': 'улица Московская 134',
  'farmamir-toktogula-93': 'улица Токтогула 93',
  'farmamir-tunguch-64': 'микрорайон Тунгуч 64',
  'elaman-logvinenko-30': 'улица Логвиненко 30/1',
  'elaman-togoloka-moldo-1': 'улица Тоголока Молдо 1',
  'elaman-fuchika-15': 'улица Фучика 15',
  'farmservis-ahunbaeva-131': 'улица Ахунбаева 131',
  'farmservis-beishenalievoi-29': 'улица Бейшеналиевой 29',
};

function shortAddress(a = {}) {
  let road = a.road || a.pedestrian || a.neighbourhood || a.suburb || a.quarter || '';
  road = road
    .replace(/^улица\s+/i, 'ул. ')
    .replace(/\s+улица$/i, '')
    .replace(/^проспект\s+/i, 'просп. ')
    .replace(/\s+проспект$/i, '')
    .replace(/^микрорайон\s+/i, 'мкр ')
    .replace(/^переулок\s+/i, 'пер. ')
    .replace(/^бульвар\s+/i, 'бульв. ');
  if (road && !/^(ул\.|просп\.|мкр|пер\.|бульв\.)/.test(road)) road = `ул. ${road}`;
  return [road, a.house_number].filter(Boolean).join(', ');
}

async function main() {
  const branches = [];
  const seen = new Set();
  for (const [chain, query] of chains) {
    const found = await nominatim({ q: query, limit: '50', bounded: '1', viewbox: VIEWBOX });
    for (const r of found) {
      const isPharmacy = r.type === 'pharmacy' || r.category === 'healthcare';
      const key = `${r.osm_type}${r.osm_id}`;
      if (!isPharmacy || seen.has(key)) continue;
      seen.add(key);
      branches.push({
        osm: key,
        chain,
        name: r.name,
        address: shortAddress(r.address),
        hasHouseNumber: Boolean(r.address?.house_number),
        lat: Number(r.lat),
        lng: Number(r.lon),
        openingHours: r.extratags?.opening_hours ?? null,
        phone: r.extratags?.phone ?? r.extratags?.['contact:phone'] ?? null,
      });
    }
    console.log(`${chain}: ${branches.filter((b) => b.chain === chain).length}`);
  }

  // Точные координаты адресов из плана (только если найден сам дом).
  const known = {};
  for (const [id, q] of Object.entries(knownAddresses)) {
    const [r] = await nominatim({ q: `${q}, Бишкек`, limit: '1' });
    const wanted = q.split(' ').pop();
    const house = r?.address?.house_number?.split(/[\s,]/)[0] ?? '';
    // «64/5» — корпус того же дома 64 (жилой комплекс) — тоже подходит.
    if (r && (house === wanted || house.startsWith(`${wanted}/`))) {
      known[id] = { lat: Number(r.lat), lng: Number(r.lon), found: r.display_name };
      console.log(`✓ ${id}: ${r.lat}, ${r.lon}`);
    } else {
      console.log(`✗ ${id}: дом не найден${r ? ` (ближайшее: ${r.display_name})` : ''}`);
    }
  }

  const out = {
    source: 'OpenStreetMap через Nominatim, © участники OpenStreetMap, ODbL',
    fetchedAt: new Date().toISOString().slice(0, 10),
    known,
    branches,
  };
  const target = path.join(__dirname, '..', 'assets', 'osm_pharmacies.json');
  fs.writeFileSync(target, JSON.stringify(out, null, 2) + '\n', 'utf8');
  console.log(`OK: ${branches.length} аптек, ${Object.keys(known).length} точных адресов → ${target}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
