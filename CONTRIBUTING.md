# Contributing

Thanks for helping with Retrofind.

By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a bug or asking for a feature

Open an [issue](https://github.com/Gitguy268/retrofind/issues/new/choose) and use the template. Say which browser and macOS versions you use.

Report security problems privately: see [SECURITY.md](SECURITY.md).

## Making a change

1. Fork the repository and create a branch from `main`.
2. Install once with `sh searxng/install.sh`. It runs `server.py` straight from your clone, so edits to `web/` show up on reload. After editing `server.py`, restart it:
   ```sh
   launchctl kickstart -k gui/$(id -u)/org.retrofind.web
   ```
3. Keep commits small, each with a clear message.
4. Run the checks below, and update the README if behaviour changed.
5. Open a pull request and fill in the template.

## Checks

```sh
python3 -m unittest discover tests
shellcheck start.command searxng/*.sh searxng/*.command
```

Then try it in a browser: the start page, a search, paging, "I'm Feeling Lucky", and a search with SearXNG stopped (`launchctl bootout gui/$(id -u)/org.retrofind.searxng`), which should show the error box.

## Ground rules

- No build step and no runtime dependencies beyond Python's standard library and the vendored glass files.
- Search results are untrusted. Build them with `textContent`, never `innerHTML`, and keep the `http`/`https` check in `server.py`.
- New code, images or fonts from other projects need a compatible licence and a line in `NOTICE`. Copyleft and unlicensed projects may inspire ideas, but no code.
