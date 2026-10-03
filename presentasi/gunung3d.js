/* RentGear, gunung 3D di latar deck (three.js).
   Dimuat sebelum deck.js. deck.js memanggil bangunGunung3d sekali, lalu atur() tiap kali ketinggian berubah. */

/** Derau nilai 2D berlapis (0 sampai 1). `tajam` melipat tiap lapis supaya jadi punggungan runcing. */
function derau2(r) {
  const kisi = Float32Array.from({ length: 65536 }, r);
  const ambil = (i, j) => kisi[((j & 255) << 8) | (i & 255)];
  const halus = (f) => f * f * (3 - 2 * f);
  const dasar = (x, z) => {
    const i = Math.floor(x);
    const j = Math.floor(z);
    const u = halus(x - i);
    const v = halus(z - j);
    const atas = ambil(i, j) * (1 - u) + ambil(i + 1, j) * u;
    const bawah = ambil(i, j + 1) * (1 - u) + ambil(i + 1, j + 1) * u;
    return atas * (1 - v) + bawah * v;
  };
  return (x, z, oktaf, tajam) => {
    let jumlah = 0;
    let amp = 0.5;
    let total = 0;
    for (let o = 0; o < oktaf; o++) {
      const n = dasar(x, z);
      jumlah += amp * (tajam ? 1 - Math.abs(2 * n - 1) : n);
      total += amp;
      amp /= 2;
      x *= 2;
      z *= 2;
    }
    return jumlah / total;
  };
}

/** Prisma segitiga untuk tenda: setengah lebar L, tinggi T, setengah panjang P. Dipakai juga oleh aksi3d.js. */
function prismaTenda(L, T, P) {
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute([
    -L, 0, P, L, 0, P, 0, T, P,
    L, 0, -P, -L, 0, -P, 0, T, -P,
    -L, 0, -P, -L, 0, P, 0, T, P, -L, 0, -P, 0, T, P, 0, T, -P,
    L, 0, P, L, 0, -P, 0, T, -P, L, 0, P, 0, T, -P, 0, T, P,
  ], 3));
  geo.computeVertexNormals();
  return geo;
}

/** Bangun adegan gunung di `kanvas`. Mengembalikan null bila WebGL tidak tersedia,
    supaya deck.js tetap memakai punggungan SVG. */
function bangunGunung3d(kanvas, { acak, tenang }) {
  if (!window.THREE) return null;
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas: kanvas, alpha: true, antialias: true });
  } catch {
    return null;
  }
  const { clamp, smoothstep } = THREE.MathUtils;
  const r = acak(2024);
  const nilai = derau2(acak(411));

  /* ---------- medan ---------- */

  const KERUCUT = { x: 60, z: -330 };
  const KEMAH = { x: 20, z: 12 };
  // Lapangan terbuka di antara kamera pertama dan tenda.
  const LAPANGAN = { x: 10, z: 46, jari: 42 };

  /** Tinggi tanah di (x, z). Lembah basecamp ada di z positif, puncak utama di sekitar KERUCUT,
      dan pegunungan yang lebih rendah di baliknya. */
  function tinggi(x, z) {
    const jauh = clamp((60 - z) / 400, 0, 1);
    const lewat = clamp((-480 - z) / 350, 0, 1);
    const amp = (6 + 150 * jauh ** 1.3) * (1 - 0.5 * lewat);
    const punggung = nilai(x * 0.0042, z * 0.0042, 5, true) ** 1.5;
    const jarak = Math.hypot(x - KERUCUT.x, z - KERUCUT.z);
    const kerucut = 170 * Math.exp(-((jarak / 140) ** 2));
    const kasar = nilai(x * 0.03 + 9, z * 0.03 + 9, 2, false) * 5 * jauh;
    return punggung * amp + kerucut * (0.8 + 0.2 * punggung) + kasar;
  }
  // Derau menggeser titik tertinggi dari pusat kerucut, jadi puncak dicari di sekitarnya.
  const PUNCAK = { ...KERUCUT };
  let tinggiPuncak = 0;
  for (let x = KERUCUT.x - 80; x <= KERUCUT.x + 80; x += 4) {
    for (let z = KERUCUT.z - 80; z <= KERUCUT.z + 80; z += 4) {
      const y = tinggi(x, z);
      if (y > tinggiPuncak) [tinggiPuncak, PUNCAK.x, PUNCAK.z] = [y, x, z];
    }
  }

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x12282a, 120, 1250);

  const LEBAR = 1600;
  const DALAM = 1700;
  const geoMedan = new THREE.PlaneGeometry(LEBAR, DALAM, 250, 266);
  geoMedan.rotateX(-Math.PI / 2);
  geoMedan.translate(0, 0, 120 - DALAM / 2);
  const letak = geoMedan.attributes.position;
  const warna = new Float32Array(letak.count * 3);
  const hutan = new THREE.Color(0x12281f);
  const batu = new THREE.Color(0x35494a);
  const salju = new THREE.Color(0xd6e2dd);
  const warnaTitik = new THREE.Color();
  for (let n = 0; n < letak.count; n++) {
    const y = tinggi(letak.getX(n), letak.getZ(n));
    letak.setY(n, y);
    warnaTitik.copy(hutan)
      .lerp(batu, smoothstep(y, 25, 150))
      .lerp(salju, smoothstep(y, tinggiPuncak * 0.72, tinggiPuncak * 0.93))
      .multiplyScalar(0.85 + r() * 0.3)
      .toArray(warna, n * 3);
  }
  geoMedan.setAttribute('color', new THREE.BufferAttribute(warna, 3));
  geoMedan.computeVertexNormals();
  scene.add(new THREE.Mesh(geoMedan, new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true })));

  /* ---------- pohon, tenda, api unggun ---------- */

  const JUMLAH_POHON = 1400;
  const geoPohon = new THREE.ConeGeometry(1, 3, 5);
  geoPohon.translate(0, 1.5, 0);
  const pohon = new THREE.InstancedMesh(geoPohon, new THREE.MeshLambertMaterial({ color: 0x0f2a1e, flatShading: true }), JUMLAH_POHON);
  const benda = new THREE.Object3D();
  let tertanam = 0;
  while (tertanam < JUMLAH_POHON) {
    const x = (r() - 0.5) * 760;
    const z = 110 - r() * 520;
    const y = tinggi(x, z);
    // Pohon hanya tumbuh di lereng rendah, dan lapangan kemah dibiarkan kosong.
    if (y > 95 || Math.hypot(x - LAPANGAN.x, z - LAPANGAN.z) < LAPANGAN.jari) continue;
    const besar = 1.2 + r() * 1.5;
    benda.position.set(x, y - 0.5, z);
    benda.rotation.y = r() * Math.PI;
    benda.scale.set(besar, besar * (1 + r() * 0.5), besar);
    benda.updateMatrix();
    pohon.setMatrixAt(tertanam++, benda.matrix);
  }
  scene.add(pohon);

  // Tenda dengan pintu menghadap api unggun.
  const geoTenda = prismaTenda(5, 6.5, 6);
  const tenda = new THREE.Mesh(geoTenda, new THREE.MeshLambertMaterial({ color: 0xf08a3c, emissive: 0x4a1f08, flatShading: true }));
  tenda.position.set(KEMAH.x, tinggi(KEMAH.x, KEMAH.z) - 0.3, KEMAH.z);
  tenda.rotation.y = -0.5;
  scene.add(tenda);

  const titikApi = new THREE.Vector3(KEMAH.x - 13, 0, KEMAH.z + 9);
  titikApi.y = tinggi(titikApi.x, titikApi.z) + 1;
  const bara = new THREE.Mesh(new THREE.IcosahedronGeometry(0.9, 0), new THREE.MeshBasicMaterial({ color: 0xffb060, fog: false }));
  bara.position.copy(titikApi);
  const api = new THREE.PointLight(0xff8a3a, 0, 110, 1.6);
  api.position.copy(titikApi).y += 2;
  scene.add(bara, api);

  /* ---------- cahaya ---------- */

  const langit = new THREE.HemisphereLight(0x35505a, 0x0a1410, 1);
  const matahari = new THREE.DirectionalLight(0xff8a4a, 1);
  const bulan = new THREE.DirectionalLight(0x7fa6b8, 1);
  bulan.position.set(-300, 400, 300);
  scene.add(langit, matahari, bulan);

  // Tiap warna punya tiga keadaan: senja di basecamp, malam di lereng, fajar di puncak.
  const tigaWarna = (senja, malam, fajar) => [senja, malam, fajar].map((hex) => new THREE.Color(hex));
  const WARNA = {
    kabut: tigaWarna(0x4d4a40, 0x12282a, 0xc08a66),
    langit: tigaWarna(0x5a6468, 0x2a4650, 0xf0c0a0),
    matahari: tigaWarna(0xff8a4a, 0xff8a4a, 0xffd9a0),
  };
  const campur = (hasil, [senja, malam, fajar], kadarSenja, kadarFajar) =>
    hasil.copy(malam).lerp(senja, kadarSenja).lerp(fajar, kadarFajar);

  /* ---------- kamera ---------- */

  const camera = new THREE.PerspectiveCamera(52, 1, 1, 2600);
  const diAtasTanah = (x, z, naik) => new THREE.Vector3(x, tinggi(x, z) + naik, z);
  // Rute pendakian: dari lapangan kemah, menyusuri lereng kiri, sampai berdiri di puncak.
  const rute = new THREE.CatmullRomCurve3([
    diAtasTanah(0, 82, 8),
    diAtasTanah(-80, -40, 20),
    diAtasTanah(-150, -170, 40),
    diAtasTanah(-80, -310, 46),
    diAtasTanah(PUNCAK.x, PUNCAK.z, 14),
  ]);
  // Arah pandang: menatap puncak selama mendaki, lalu ke pegunungan di baliknya saat sampai.
  const pandang = new THREE.CatmullRomCurve3([
    new THREE.Vector3(PUNCAK.x, tinggiPuncak * 0.42, PUNCAK.z),
    new THREE.Vector3(PUNCAK.x, tinggiPuncak * 0.8, PUNCAK.z),
    new THREE.Vector3(PUNCAK.x + 20, tinggiPuncak, PUNCAK.z - 20),
    new THREE.Vector3(PUNCAK.x + 90, tinggiPuncak, PUNCAK.z - 260),
    new THREE.Vector3(PUNCAK.x + 190, tinggiPuncak - 60, PUNCAK.z - 800),
  ]);
  const mata = new THREE.Vector3();
  const sasaran = new THREE.Vector3();

  const keadaan = { p: 0, fajar: 0, tilikX: 0, tilikY: 0 };
  let kotor = true;

  function gambar(kini) {
    const detik = tenang ? 0 : kini / 1000;
    const { p, fajar, tilikX, tilikY } = keadaan;
    const senja = clamp(1 - p / 0.5, 0, 1);

    rute.getPoint(p, mata);
    pandang.getPoint(p, sasaran);
    // Kamera berayun pelan dan ikut bergeser dengan penunjuk, supaya kedalaman medan terlihat.
    mata.x += Math.sin(detik * 0.23) * 1.6 + tilikX * 12;
    mata.y += Math.cos(detik * 0.19) * 0.7 - tilikY * 5;
    mata.y = Math.max(mata.y, tinggi(mata.x, mata.z) + 5);
    camera.position.copy(mata);
    camera.lookAt(sasaran);

    campur(scene.fog.color, WARNA.kabut, senja, fajar);
    campur(langit.color, WARNA.langit, senja, fajar);
    campur(matahari.color, WARNA.matahari, senja, fajar);
    langit.intensity = 0.9 + 0.5 * senja + 0.9 * fajar;
    matahari.intensity = 1.4 * senja + 3.2 * fajar;
    matahari.position.set(sasaran.x + 420, sasaran.y + 40 + 260 * fajar, sasaran.z - 900);
    bulan.intensity = 1.4 + 1.4 * (1 - senja) * (1 - fajar) - 0.8 * fajar;
    // Api unggun berkedip, lalu padam begitu kamera meninggalkan basecamp.
    const nyala = clamp(1 - p / 0.25, 0, 1);
    api.intensity = 520 * nyala * (0.82 + 0.12 * Math.sin(detik * 11) + 0.06 * Math.sin(detik * 23.7));
    bara.scale.setScalar(nyala * (1 + 0.15 * Math.sin(detik * 13)));

    renderer.render(scene, camera);
  }

  function putaran(kini) {
    if (kotor || !tenang) gambar(kini);
    kotor = false;
    requestAnimationFrame(putaran);
  }
  requestAnimationFrame(putaran);

  return {
    /** Setel ketinggian p (0 basecamp, 1 puncak), kadar fajar, dan posisi penunjuk. */
    atur(p, fajar, tilik) {
      Object.assign(keadaan, { p: clamp(p, 0, 1), fajar, tilikX: tilik.x, tilikY: tilik.y });
      kotor = true;
    },
    ukur() {
      renderer.setPixelRatio(Math.min(1.5, devicePixelRatio || 1));
      renderer.setSize(innerWidth, innerHeight, false);
      camera.aspect = innerWidth / innerHeight;
      camera.updateProjectionMatrix();
      kotor = true;
    },
  };
}
