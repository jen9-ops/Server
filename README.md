# Self‑Server (Service Worker) — для GitHub Pages


**Что это:** Обычная страница `index.html`, которая по кнопке регистрирует `sw.js`. Service Worker начинает перехватывать запросы в пределах текущего каталога (repo path) и предоставляет локальный API: `api/run`, `api/save/:key`, `api/load/:key`. Включён CORS и IndexedDB‑KV.


## Развёртывание
1. Склонируйте/создайте репозиторий и положите в корень `index.html` и `sw.js`.
2. В настройках GitHub → Pages включите публикацию из ветки `main` (папка `/`), либо из `/docs` (если файлы в `docs/`).
3. Откройте выданный `https://<user>.github.io/<repo>/`.
4. Нажмите **Start server (SW)** — страница перезагрузится и будет обслуживаться Service Worker (в заголовке появится пометка).


## Важно
- Путь **автоматически** учитывает `<repo>` (работает и с корнем `user.github.io`).
- Для запросов используйте относительные к базовому пути URL: `BASE + 'api/run'` и т.п. (в `index.html` это делается автоматически).
- CORS: ответы содержат `Access-Control-Allow-*`, preflight (`OPTIONS`) поддерживается.
- IndexedDB: простой KV-хранилище (`save/load`).
