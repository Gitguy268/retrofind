// Copyright (c) 2026 Lucas Van De Weerd. MIT.
import { createLiquidGlass } from './vendor/liquid-glass-web/liquid-glass.js';
import { paintDesktop } from './wallpaper.js';

const $ = (id) => document.getElementById(id);
const params = new URLSearchParams(location.search);

function showError(text) {
  $('errorText').textContent = text;
  if (!$('error').open) $('error').showModal();
}

function element(tag, props = {}, ...children) {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children);
  return node;
}

const ink = { R: 'blue', e: 'red', t: 'yellow', r: 'blue', o: 'yellow', f: 'red', i: 'blue', n: 'yellow', d: 'green' };
const letter = (c) => element('span', { className: `logo ${ink[c]}`, textContent: c });

// Results come from server.py, which keeps only http(s) links. Text is never parsed as HTML.
function renderResults(data, page, seconds) {
  const query = params.get('q');
  $('summary').replaceChildren(
    'Searched the web for ',
    element('b', { textContent: query }),
    data.results.length
      ? `. Page ${page}, ${data.results.length} results. Search took ${seconds} seconds.`
      : `. No ${page > 1 ? 'more ' : ''}results.`,
  );
  const link = (text) => {
    const next = new URLSearchParams(params);
    next.set('q', text);
    next.delete('pageno');
    return element('a', { href: `/search?${next}`, textContent: text });
  };
  const notes = [
    ...data.answers.map((a) => element('p', { className: 'answer', textContent: a })),
    ...[...data.corrections, ...data.suggestions].slice(0, 5).map((s) => element('p', {}, 'Did you mean: ', link(s))),
  ];
  $('notes').replaceChildren(...notes);
  $('list').replaceChildren(
    ...data.results.map((r) =>
      element(
        'li',
        {},
        element('a', { href: r.url, textContent: r.title }),
        r.content ? element('p', { className: 'snippet', textContent: r.content }) : '',
        element('span', { className: 'url', textContent: r.url.replace(/^https?:\/\//, '') }),
        element('span', { className: 'engine', textContent: ` - ${r.engines.join(', ')}` }),
      ),
    ),
  );
  // We never learn the total, so offer four pages past this one while results keep coming.
  const last = data.results.length ? page + 4 : page;
  const pages = [];
  for (let n = Math.max(1, last - 9); n <= last; n++) {
    const go = new URLSearchParams(params);
    go.set('pageno', n);
    const o = [letter('o'), element('span', { className: 'num', textContent: n })];
    pages.push(n === page ? element('b', {}, ...o) : element('a', { href: `/search?${go}`, ariaLabel: `Page ${n}` }, ...o));
  }
  $('pager').replaceChildren(...[...'Retr'].map(letter), ...pages, ...[...'find'].map(letter));
}

async function search() {
  const page = Math.max(1, parseInt(params.get('pageno'), 10) || 1);
  const query = params.get('q') || '';
  $('home').hidden = true;
  $('results').hidden = false;
  $('q').value = query;
  $('category').value = params.get('categories') || 'general';
  document.title = 'Retrofind Search';
  $('windowTitle').textContent = `Retrofind Search: ${query}`;
  $('status').textContent = 'Opening page…';
  const started = performance.now();
  let data;
  try {
    const reply = await fetch(`/api/search?${new URLSearchParams({ q: query, pageno: page, categories: $('category').value })}`);
    data = await reply.json();
    if (!reply.ok) throw new Error(data.error);
  } catch (error) {
    $('summary').textContent = 'The page cannot be displayed.';
    $('status').textContent = 'Error';
    showError(`${error.message || 'Retrofind cannot reach SearXNG.'} Double-click start.command in the Retrofind folder.`);
    return;
  }
  if (params.has('lucky') && data.results.length) return location.replace(data.results[0].url);
  params.delete('lucky'); // or every pager and suggestion link would jump too
  renderResults(data, page, ((performance.now() - started) / 1000).toFixed(2));
  $('status').textContent = 'Done';
}

function windowControls() {
  const win = $('window'),
    task = $('task');
  const show = (visible) => {
    win.hidden = !visible;
    task.setAttribute('aria-pressed', String(visible));
  };
  $('minimize').onclick = $('close').onclick = () => show(false);
  task.onclick = () => show(win.hidden);
  $('maximize').onclick = () => win.classList.toggle('maximized');
  $('back').onclick = () => history.back();
  $('forward').onclick = () => history.forward();
  $('address').value = location.href;
  const tick = () => ($('clock').textContent = new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }));
  tick();
  setInterval(tick, 15000);
}

function glass() {
  const motion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const surfaces = [
    ['.window', { refraction: 42, blur: 2, light: 40 }],
    ['.window > .titlebar', { refraction: 58, light: 70 }],
    ['.taskbar', { refraction: 58, light: 60 }],
    ['.start, .task', { refraction: 72, light: 70 }],
  ];
  for (const [selector, options] of surfaces) {
    for (const node of document.querySelectorAll(selector)) {
      try {
        createLiquidGlass(node, { radius: 0, pointer: !motion, ...options });
      } catch {
        // Without glass the chrome keeps its solid Win98 look.
      }
    }
  }
}

paintDesktop($('desktop'));
addEventListener('resize', () => paintDesktop($('desktop')));
windowControls();
glass();
if (params.get('q')?.trim()) search();
