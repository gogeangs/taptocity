# Persistent city playable preview

Open https://gogeangs.github.io/taptocity/preview/native-play/full/ . The existing game shell, canvas and approved sprite assets are reused; clearing and free construction now share one isometric map. Production, residents, a 240-second day (180 day / 60 night), ash cleanup, tower protection, building upgrades, and six sequential goals are enabled. The old story simulation is paused in this preview to avoid competing map progression.

Saves are isolated under `ttc-integrated-preview-v1:`. Existing city saves migrate on first play. No cloud sync, service worker registration or offline income. The two regions each have 625 tiles; the eastern region unlocks from the eastern border. Night ash stops affected buildings' production, never deletes land or structures. Residents here are city population, not recruited story characters.

Tests: `node --test tests/city-sim.test.cjs` from this directory. Pure city-core rules are tested separately in repository tests/city.test.cjs.
