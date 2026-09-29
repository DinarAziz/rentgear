# RentGear — Web build (static)

Compiled Flutter web release of `rentgear_app`. Serve this folder as-is; no build step needed.

## Serve on the Redmi phone (Termux)

```bash
pkg install python
cd webapp
python -m http.server 8080
```

Open `http://localhost:8080` on the phone, or `http://<phone-ip>:8080` from another device on the same network.

Alternative (Node, if installed):

```bash
npx serve -l 8080 .
```

## Rebuilding after a source change

From `rentgear_app/`:

```bash
flutter build web --release
```

Then copy `rentgear_app/build/web/*` back into this `webapp/` folder.
