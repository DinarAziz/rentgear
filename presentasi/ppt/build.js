// Build the PowerPoint copy of the web deck from step screenshots.
// Each web step becomes a full-slide picture that fades in on click.
// With a third argument "tanpa-animasi": one picture per slide in its final state, with no click animation and no
// slide transition. Slides whose later step replaces a whole panel (PANEL_BERGANTI) keep every step as its own slide;
// other slides that hide something (the double-booking walk-through) end on a state that already sums up the slide.
const pptxgen = require('pptxgenjs');
const sharp = require('sharp');
const JSZip = require('jszip');
const fs = require('fs');

const [shots, outFile, mode] = process.argv.slice(2);
const still = mode === 'tanpa-animasi';
const PANEL_BERGANTI = ['implementasi', 'pengujian'];
const meta = JSON.parse(fs.readFileSync(`${shots}/meta.json`));
const W = 13.333, H = 7.5, PX = W / 1920;

const jpeg = async (f) => 'image/jpeg;base64,' + (await sharp(`${shots}/${f}`).jpeg({ quality: 88, mozjpeg: true }).toBuffer()).toString('base64');

async function build() {
  const pres = new pptxgen();
  pres.layout = 'LAYOUT_WIDE';
  pres.title = 'RentGear';
  pres.subject = 'Marketplace penyewaan alat hiking dan camping';
  pres.author = 'Dinar Aziz Al Ghifari';

  let section = null;
  for (const m of meta) {
    if (m.pos !== section) { section = m.pos; pres.addSection({ title: m.pos }); }
    if (still) {
      for (const f of PANEL_BERGANTI.includes(m.id) ? m.files : m.files.slice(-1)) {
        const slide = pres.addSlide({ sectionTitle: m.pos });
        slide.background = { color: '0E1A17' };
        slide.addImage({ data: await jpeg(f), x: 0, y: 0, w: W, h: H, objectName: 'halaman', altText: m.text.split('\n').slice(0, 2).join(' — ') });
        slide.addNotes(m.text);
      }
      continue;
    }
    const slide = pres.addSlide({ sectionTitle: m.pos });
    slide.background = { color: '0E1A17' };
    for (const [k, f] of m.files.entries()) {
      slide.addImage({ data: await jpeg(f), x: 0, y: 0, w: W, h: H, objectName: `langkah-${k}`, altText: k ? `${m.label}, langkah ${k}` : m.text.split('\n').slice(0, 2).join(' — ') });
    }
    slide.addNotes(m.text);
  }
  await pres.writeFile({ fileName: outFile });
}

// Fade-in on click for every step picture, plus a fade transition between slides.
function timing(ids) {
  let n = 2;
  const clicks = ids.map((id) => `<p:par><p:cTn id="${++n}" fill="hold"><p:stCondLst><p:cond delay="indefinite"/></p:stCondLst><p:childTnLst><p:par><p:cTn id="${++n}" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst><p:par><p:cTn id="${++n}" presetID="10" presetClass="entr" presetSubtype="0" fill="hold" nodeType="clickEffect"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst><p:set><p:cBhvr><p:cTn id="${++n}" dur="1" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst></p:cTn><p:tgtEl><p:spTgt spid="${id}"/></p:tgtEl><p:attrNameLst><p:attrName>style.visibility</p:attrName></p:attrNameLst></p:cBhvr><p:to><p:strVal val="visible"/></p:to></p:set><p:animEffect transition="in" filter="fade"><p:cBhvr><p:cTn id="${++n}" dur="500"/><p:tgtEl><p:spTgt spid="${id}"/></p:tgtEl></p:cBhvr></p:animEffect></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par>`).join('');
  return `<p:timing><p:tnLst><p:par><p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst><p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst>${clicks}</p:childTnLst></p:cTn><p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst><p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst></p:seq></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>`;
}

async function animate() {
  const zip = await JSZip.loadAsync(fs.readFileSync(outFile));
  for (const name of Object.keys(zip.files).filter((f) => /^ppt\/slides\/slide\d+\.xml$/.test(f))) {
    let xml = await zip.file(name).async('string');
    const ids = [...xml.matchAll(/<p:cNvPr id="(\d+)" name="langkah-(\d+)"/g)].filter((m) => m[2] !== '0').map((m) => m[1]);
    const hasTiming = xml.includes('<p:timing');
    let extra = '<p:transition spd="med"><p:fade/></p:transition>';
    if (ids.length && !hasTiming) extra += timing(ids);
    if (ids.length && hasTiming) throw new Error(`${name} already has timing`);
    xml = xml.replace('</p:clrMapOvr>', '</p:clrMapOvr>' + extra);
    zip.file(name, xml);
  }
  fs.writeFileSync(outFile, await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' }));
}

build().then(() => (still ? null : animate())).then(() => console.log('done', outFile));
