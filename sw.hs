// ==== БАЗОВЫЕ НАСТРОЙКИ ДЛЯ GITHUB PAGES ====
const BASE = new URL(self.registration.scope).pathname.replace(/\/+$/, ''); // например: "/repo"
const CACHE_NAME = 'self-server-v4';
const ASSETS = [ `${BASE}/`, `${BASE}/index.html`, `${BASE}/sw.js` ];


// ===== Helpers =====
const jsonResponse = (obj, status = 200, hdr = {}) =>
new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...hdr } });
const textResponse = (txt, status = 200, hdr = {}) =>
new Response(txt, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8', ...hdr } });
const htmlResponse = (html, status = 200) =>
new Response(html, { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } });


// ===== IndexedDB mini‑KV =====
const DB_NAME = 'self-server-db';
const STORE = 'kv';
function idbOpen(){ return new Promise((resolve, reject)=>{ const req = indexedDB.open(DB_NAME, 1); req.onupgradeneeded = ()=>{ const db=req.result; if(!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE); }; req.onsuccess=()=>resolve(req.result); req.onerror=()=>reject(req.error); }); }
async function kvSet(key,val){ const db=await idbOpen(); return new Promise((res,rej)=>{ const tx=db.transaction(STORE,'readwrite'); tx.objectStore(STORE).put(val,key); tx.oncomplete=()=>res(); tx.onerror=()=>rej(tx.error); }); }
async function kvGet(key){ const db=await idbOpen(); return new Promise((res,rej)=>{ const tx=db.transaction(STORE,'readonly'); const rq=tx.objectStore(STORE).get(key); rq.onsuccess=()=>res(rq.result); rq.onerror=()=>rej(rq.error); }); }


// ===== Class Router (относительно BASE) =====
class Router {
constructor(basePath){ this.base = basePath; this.routes=[]; this.mw=[]; }
use(fn){ this.mw.push(fn); }
add(method, path, handler){ const { re, keys } = this._compile(path); this.routes.push({ method: method.toUpperCase(), re, keys, handler }); }
get(p,h){ this.add('GET',p,h); } post(p,h){ this.add('POST',p,h); } put(p,h){ this.add('PUT',p,h); } del(p,h){ this.add('DELETE',p,h); }
async handle(event){
const req = event.request; const url = new URL(req.url);
if (url.origin !== self.location.origin) return fetch(req);
const path = url.pathname;
for (const r of this.routes){ if (r.method !== req.method.toUpperCase()) continue; const m=r.re.exec(path); if(!m) continue;
const params={}; r.keys.forEach((k,i)=> params[k]=decodeURIComponent(m[i+1]||''));
const ctx = { event, req, url, params, text:()=>req.clone().text(), json:()=>req.clone().json(), arrayBuffer:()=>req.clone().arrayBuffer() };
let i=-1; const run = async (n)=>{ if(n<=i) throw new Error('next() twice'); i=n; if(n===this.mw.length) return r.handler(ctx); return this.mw[n](ctx, ()=>run(n+1)); };
return await run(0);
}
return caches.match(req).then(r=> r || fetch(req));
}
_compile(path){
const keys=[];
const norm = (p)=> (this.base + '/' + p.replace(/^\/+/, '')) .replace(/\/{2,}/g,'/');
const target = norm(path); // всегда относительный к BASE
const reStr = target
.replace(/([.+?^=!:${}()[\]|\/\\])/g, '\\$1')
.replace(/\*/g, '.*?')
.replace(/:(\w+)/g, (_,k)=>{ keys.push(k); return '([^/]+)'; });
return { re: new RegExp('^'+reStr+'/?$'), keys };
}
}


// ===== Install/activate =====
self.addEventListener('install', e => {
e.waitUntil(
caches.open(CACHE_NAME).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())
);
});
self.addEventListener('activate', e => { e.waitUntil(self.clients.claim()); });
self.addEventListener('message', e => { if (e.data?.type === 'CLAIM') self.clients.claim(); });


self.addEventListener('fetch', evt => { evt.respondWith(router.handle(evt)); });
