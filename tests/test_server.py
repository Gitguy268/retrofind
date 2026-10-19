# Copyright (c) 2026 Lucas Van De Weerd. MIT.
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from server import search_params, slim  # noqa: E402


class SearchParams(unittest.TestCase):
    def test_only_whitelisted_params_are_forwarded(self):
        params = search_params({'q': [' cats '], 'engines': ['x'], 'format': ['html']})
        self.assertEqual(params, {'q': 'cats', 'pageno': 1, 'categories': 'general', 'format': 'json'})

    def test_empty_query_is_refused(self):
        self.assertIsNone(search_params({'q': ['   ']}))
        self.assertIsNone(search_params({}))

    def test_pageno_is_clamped(self):
        self.assertEqual(search_params({'q': ['a'], 'pageno': ['999']})['pageno'], 50)
        self.assertEqual(search_params({'q': ['a'], 'pageno': ['-3']})['pageno'], 1)
        self.assertEqual(search_params({'q': ['a'], 'pageno': ['two']})['pageno'], 1)

    def test_unknown_category_falls_back(self):
        self.assertEqual(search_params({'q': ['a'], 'categories': ['files']})['categories'], 'general')
        self.assertEqual(search_params({'q': ['a'], 'categories': ['news']})['categories'], 'news')


class Slim(unittest.TestCase):
    def test_only_http_links_survive(self):
        data = {'results': [
            {'url': 'javascript:alert(1)', 'title': 'x'},
            {'url': 'data:text/html,hi', 'title': 'x'},
            {'url': None},
            {'url': 'https://example.com/', 'title': '<b>Hi</b>', 'engines': ['google']},
        ]}
        self.assertEqual(slim(data)['results'], [
            {'title': '<b>Hi</b>', 'url': 'https://example.com/', 'content': '', 'engines': ['google']},
        ])

    def test_answers_accept_strings_and_objects(self):
        out = slim({'answers': ['42', {'answer': '7'}, {}], 'suggestions': ['cat']})
        self.assertEqual(out['answers'], ['42', '7'])
        self.assertEqual(out['suggestions'], ['cat'])


if __name__ == '__main__':
    unittest.main()
