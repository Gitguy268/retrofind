#!/usr/bin/env python3
# Copyright (c) 2026 Lucas Van De Weerd. MIT.
"""Serve Retrofind's pages on localhost and pass searches to a local SearXNG."""
import argparse
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import URLError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import urlopen

WEB = Path(__file__).resolve().parent / 'web'
CATEGORIES = {'general', 'news'}


def search_params(query):
    """The only parameters ever sent to SearXNG; None when there is nothing to search."""
    q = query.get('q', [''])[0].strip()[:400]
    if not q:
        return None
    try:
        pageno = min(50, max(1, int(query.get('pageno', ['1'])[0])))
    except ValueError:
        pageno = 1
    category = query.get('categories', ['general'])[0]
    return {
        'q': q,
        'pageno': pageno,
        'categories': category if category in CATEGORIES else 'general',
        'format': 'json',
    }


def safe_url(url):
    return isinstance(url, str) and urlsplit(url).scheme in ('http', 'https')


def slim(data):
    """Keep only text fields and http(s) links, so the page never gets a javascript: href."""
    texts = lambda items: [i if isinstance(i, str) else str(i.get('answer', '')) for i in items or []]
    return {
        'results': [
            {
                'title': str(r.get('title') or r['url']),
                'url': r['url'],
                'content': str(r.get('content') or ''),
                'engines': [str(e) for e in r.get('engines') or []],
            }
            for r in data.get('results', [])
            if safe_url(r.get('url'))
        ],
        'answers': [a for a in texts(data.get('answers')) if a],
        'corrections': texts(data.get('corrections')),
        'suggestions': texts(data.get('suggestions')),
    }


class Handler(SimpleHTTPRequestHandler):
    searxng = 'http://127.0.0.1:8893'

    def send_json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlsplit(self.path)
        query = parse_qs(url.query)
        if url.path == '/api/search':
            params = search_params(query)
            if params is None:
                return self.send_json(400, {'error': 'Type something to search for.'})
            try:
                with urlopen(f'{self.searxng}/search?{urlencode(params)}', timeout=20) as reply:
                    return self.send_json(200, slim(json.load(reply)))
            except (URLError, OSError, ValueError):
                return self.send_json(502, {'error': 'Retrofind cannot reach SearXNG.'})
        if url.path == '/search':
            self.path = '/index.html'
        return super().do_GET()

    def end_headers(self):
        # Results link out to other sites; never tell them what was searched.
        self.send_header('Referrer-Policy', 'no-referrer')
        super().end_headers()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8898)
    parser.add_argument('--searxng', default=Handler.searxng)
    args = parser.parse_args()
    Handler.searxng = args.searxng.rstrip('/')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(WEB)))
    print(f'Retrofind: http://127.0.0.1:{args.port}/', flush=True)
    server.serve_forever()
