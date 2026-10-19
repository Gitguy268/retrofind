# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue.

Use GitHub's private reporting form: <https://github.com/Gitguy268/retrofind/security/advisories/new>

Include what you found, how to reproduce it, and your browser and macOS versions. You should get a reply within a week. Please give the fix time to ship before you publish details.

## Scope

Retrofind is meant to be reachable only from your own computer. The most useful reports are about:

- `server.py` or SearXNG listening on anything other than `127.0.0.1`;
- `/api/search` forwarding something other than the query, page and category, or acting as an open proxy;
- a search result that runs script in the Retrofind page (for example a `javascript:` link);
- the scripts in `searxng/` leaking the secret they generate;
- the GitHub Actions workflows in this repository.

Bugs inside SearXNG itself belong to [SearXNG's security policy](https://github.com/searxng/searxng/security).
