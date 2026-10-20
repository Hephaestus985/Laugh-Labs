# Lab Arcade downloads

This branch only holds files the app and its players download. It is rewritten
on every release (a single commit), so old builds don't pile up in the history.
The source code, version history and tags live on the `main` branch.

- `apks/LabArcade.apk`: the newest app. Install link:
  https://github.com/Hephaestus985/Laugh-Labs/raw/downloads/apks/LabArcade.apk
- `packs/`: one download per game version (`<game>_v<N>-<sha>.pck`), for the newest
  app and the one before it. `packs.json` lists them with their SHA-256 fingerprints.
