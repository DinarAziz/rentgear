// Colours and type from the presentation deck (presentasi/deck.css), so the video matches the slides.
import { continueRender, delayRender, staticFile } from 'remotion';

export const C = {
  night: '#08130f',
  pine: '#10241c',
  forest: '#2e6b4f',
  moss: '#8fc3a2',
  sand: '#f3eddf',
  mist: '#b7c9bd',
  summit: '#f08a3c',
  ember: '#ffb876',
  line: 'rgba(183, 201, 189, 0.22)',
};

export const DISPLAY = '"Big Shoulders Display", "Arial Narrow", sans-serif';
export const BODY = '"Outfit", system-ui, sans-serif';

const fonts = [
  ['Big Shoulders Display', 'fonts/big-shoulders-display-latin-wght-normal.woff2'],
  ['Outfit', 'fonts/outfit-latin-wght-normal.woff2'],
] as const;

const handle = delayRender('Loading fonts');
Promise.all(
  fonts.map(([family, file]) => {
    const face = new FontFace(family, `url(${staticFile(file)}) format("woff2")`, { weight: '100 900' });
    document.fonts.add(face);
    return face.load();
  }),
).then(() => continueRender(handle));
