// ==== БАЗА ДЛЯ GITHUB PAGES (scope текущей папки) ====
const BASE = new URL(self.registration.scope).pathname.replace(/\/$/, ''); // например: "/repo"
const CACHE_NAME = 'self-server-v5';
const ASSETS = [ `${BASE}/index.html`, `${BASE}/sw.js` ];


// ===== Helpers =====
const json = (obj, status = 200, hdr = {}) => new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...hdr } });
const html = (txt, status = 200) => new Response(txt, { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } });


// ===== IndexedDB mini‑KV =====
const DB_NAME = 'self-server-db';
const STORE = 'kv';
function idbOpen(){ return new Promise((resolve, reject)=>{ const req = indexedDB.open(DB_NAME, 1); req.onupgradeneeded = ()=>{ const db=req.result; if(!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE); }; req.onsuccess=()=>resolve(req.result); req.onerror=()=>reject(req.error); }); }
async function kvSet(key,val){ const db=await idbOpen(); return new Promise((res,rej)=>{ const tx=db.transaction(STORE,'readwrite'); tx.objectStore(STORE).put(val,key); tx.oncomplete=()=>res(); tx.onerror=()=>rej(tx.error); }); }
async function kvGet(key){ const db=await idbOpen(); return new Promise((res,rej)=>{ const tx=db.transaction(STORE,'readonly'); const rq=tx.objectStore(STORE).get(key); rq.onsuccess=()=>res(rq.result); rq.onerror=()=>rej(rq.error); }); }


self.addEventListener('install', e => {
e.waitUntil(
caches.open(CACHE_NAME).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())
);
});


self.addEventListener('activate', e => { e.waitUntil(self.clients.claim()); });
self.addEventListener('message', e => { if (e.data?.type === 'CLAIM') self.clients.claim(); });


function withCORS(resp){
const h = new Headers(resp.headers);
h.set('Access-Control-Allow-Origin','*');
h.set('Access-Control-Allow-Methods','GET,POST,PUT,DELETE,OPTIONS');
h.set('Access-Control-Allow-Headers','Content-Type');
return new Response(resp.body, { status: resp.status, headers: h });
}


self.addEventListener('fetch', event => {
const url = new URL(event.request.url);
if (url.origin !== location.origin) return; // чужой origin — не трогаем


// Только в рамках BASE
if (!url.pathname.startsWith(BASE + '/')) return;


// === Preflight CORS для API ===
if (event.request.method === 'OPTIONS' && url.pathname.startsWith(BASE + '/api/')) {
event.respondWith(new Response(null, { status: 204, headers: {
'Access-Control-Allow-Origin': '*',
'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
'Access-Control-Allow-Headers': event.request.headers.get('Access-Control-Request-Headers') || 'Content-Type',
'Access-Control-Max-Age': '86400'
}}));
return;
}


// === API: POST /api/run ===
if (event.request.method === 'POST' && url.pathname === BASE + '/api/run') {
event.respondWith(withCORS(json({ ok:true, stdout: JSON.stringify({ ts:new Date().toISOString(), scope:self.registration.scope }, null, 2) })));
return;
}


// === API: POST /api/save/:key ===
if (event.request.method === 'POST' && url.pathname.startsWith(BASE + '/api/save/')) {
event.respondWith((async ()=>{
const key = decodeURIComponent(url.pathname.slice((BASE + '/api/save/').length));
const body = await event.request.text();
await kvSet(key, body);
return withCORS(json({ ok:true, saved:key, bytes: body.length }));
})());
return;
}


// === API: GET /api/load/:key ===
if (event.request.method === 'GET' && url.pathname.startsWith(BASE + '/api/load/')) {
event.respondWith((async ()=>{
const key = decodeURIComponent(url.pathname.slice((BASE + '/api/load/').length));
const val = (await kvGet(key)) ?? '';
return withCORS(json({ ok:true, key, data: val }));
})());
return;
});
