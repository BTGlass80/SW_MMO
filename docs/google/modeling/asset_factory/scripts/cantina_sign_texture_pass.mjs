import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import crypto from "node:crypto";

const PROJECT_ROOT = process.cwd();
const BASELINE = path.resolve(PROJECT_ROOT, "docs/gpt/asset_factory/generated/blockbench_cantina_entrance_v1/blockbench/blockbench_cantina_entrance_v1.bbmodel");
const OUT_ROOT = path.resolve(PROJECT_ROOT, "docs/gpt/asset_factory/generated/blockbench_cantina_sign_texture_v1");
const OUT_BB = path.join(OUT_ROOT, "blockbench");
const OUT_TEXTURES = path.join(OUT_BB, "textures");
const OUT_PREVIEWS = path.join(OUT_ROOT, "previews");

fs.mkdirSync(OUT_TEXTURES, { recursive: true });
fs.mkdirSync(OUT_PREVIEWS, { recursive: true });

function clamp(v, lo = 0, hi = 255) {
  return Math.max(lo, Math.min(hi, Math.round(v)));
}

function hexToRgb(hex, alpha = 255) {
  const clean = String(hex).replace("#", "");
  return {
    r: parseInt(clean.slice(0, 2), 16),
    g: parseInt(clean.slice(2, 4), 16),
    b: parseInt(clean.slice(4, 6), 16),
    a: alpha
  };
}

function createCanvas(width, height, color = { r: 0, g: 0, b: 0, a: 0 }) {
  const data = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    data[i * 4 + 0] = color.r;
    data[i * 4 + 1] = color.g;
    data[i * 4 + 2] = color.b;
    data[i * 4 + 3] = color.a;
  }
  return { width, height, data };
}

function setPixel(canvas, x, y, color) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  if (ix < 0 || iy < 0 || ix >= canvas.width || iy >= canvas.height) return;
  const offset = (iy * canvas.width + ix) * 4;
  canvas.data[offset + 0] = color.r;
  canvas.data[offset + 1] = color.g;
  canvas.data[offset + 2] = color.b;
  canvas.data[offset + 3] = color.a;
}

function fillRect(canvas, x, y, w, h, color) {
  for (let yy = Math.floor(y); yy < Math.ceil(y + h); yy++) {
    for (let xx = Math.floor(x); xx < Math.ceil(x + w); xx++) {
      setPixel(canvas, xx, yy, color);
    }
  }
}

function drawLine(canvas, x0, y0, x1, y1, color, thickness = 1) {
  const dx = x1 - x0;
  const dy = y1 - y0;
  const steps = Math.max(Math.abs(dx), Math.abs(dy), 1);
  const radius = Math.floor(thickness / 2);
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const x = x0 + dx * t;
    const y = y0 + dy * t;
    for (let yy = -radius; yy <= radius; yy++) {
      for (let xx = -radius; xx <= radius; xx++) {
        setPixel(canvas, x + xx, y + yy, color);
      }
    }
  }
}

function drawCircle(canvas, cx, cy, radius, color, thickness = 2) {
  const steps = Math.ceil(Math.PI * radius * 2.5);
  for (let i = 0; i < steps; i++) {
    const a = (Math.PI * 2 * i) / steps;
    const x = cx + Math.cos(a) * radius;
    const y = cy + Math.sin(a) * radius;
    fillRect(canvas, x - thickness / 2, y - thickness / 2, thickness, thickness, color);
  }
}

function crc32(buffer) {
  let table = crc32.table;
  if (!table) {
    table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c >>> 0;
    }
    crc32.table = table;
  }
  let c = 0xffffffff;
  for (const byte of buffer) c = table[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const name = Buffer.from(type);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([name, data])), 0);
  return Buffer.concat([len, name, data, crc]);
}

function encodePng(canvas) {
  const raw = Buffer.alloc((canvas.width * 4 + 1) * canvas.height);
  for (let y = 0; y < canvas.height; y++) {
    const row = y * (canvas.width * 4 + 1);
    raw[row] = 0;
    canvas.data.copy(raw, row + 1, y * canvas.width * 4, (y + 1) * canvas.width * 4);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(canvas.width, 0);
  header.writeUInt32BE(canvas.height, 4);
  header[8] = 8;
  header[9] = 6;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk("IHDR", header),
    pngChunk("IDAT", zlib.deflateSync(raw)),
    pngChunk("IEND", Buffer.alloc(0))
  ]);
}

function savePng(canvas, filePath) {
  fs.writeFileSync(filePath, encodePng(canvas));
}

function drawNoDroidsTexture() {
  const canvas = createCanvas(128, 64, hexToRgb("#d6c198"));
  const dark = hexToRgb("#1b1a18");
  const panel = hexToRgb("#a68c61");
  const droid = hexToRgb("#6e5d3a");
  const red = hexToRgb("#be392c");
  const light = hexToRgb("#f0dfb8");

  fillRect(canvas, 0, 0, 128, 4, panel);
  fillRect(canvas, 0, 60, 128, 4, panel);
  fillRect(canvas, 0, 0, 4, 64, panel);
  fillRect(canvas, 124, 0, 4, 64, panel);
  fillRect(canvas, 13, 9, 102, 46, light);

  // Original blockcraft service-droid pictogram. It is intentionally generic.
  fillRect(canvas, 54, 22, 22, 20, droid);
  fillRect(canvas, 50, 14, 30, 11, droid);
  fillRect(canvas, 57, 17, 5, 5, dark);
  fillRect(canvas, 69, 17, 5, 5, dark);
  fillRect(canvas, 43, 30, 11, 5, droid);
  fillRect(canvas, 76, 30, 11, 5, droid);
  fillRect(canvas, 59, 42, 5, 8, droid);
  fillRect(canvas, 69, 42, 5, 8, droid);
  drawLine(canvas, 53, 13, 47, 7, droid, 2);
  drawLine(canvas, 79, 13, 85, 7, droid, 2);

  drawCircle(canvas, 65, 32, 28, red, 5);
  drawLine(canvas, 41, 53, 88, 11, red, 7);
  return canvas;
}

function makeCandidateModel() {
  const baseline = JSON.parse(fs.readFileSync(BASELINE, "utf8").replace(/^\uFEFF/, ""));
  const model = structuredClone(baseline);
  model.name = "Blockbench Cantina Sign Texture v1";
  model.model_identifier = "blockbench_cantina_sign_texture_v1";
  model.codex_source = {
    ...model.codex_source,
    asset_id: "blockbench_cantina_sign_texture_v1",
    generator: "docs/gpt/asset_factory/scripts/cantina_sign_texture_pass.mjs",
    baseline_asset_id: "blockbench_cantina_entrance_v1",
    changed_variable: "no-droids sign panel texture only"
  };
  model.codex_palette = {
    ...model.codex_palette,
    sign_texture_panel: "#d6c198"
  };
  model.codex_texture_materials = {
    sign_texture_panel: "textures/no_droids_sign_panel_v1.png"
  };
  model.elements = model.elements.filter((element) => !["sign_droid_body", "sign_droid_head", "sign_red_slash"].includes(element.name));
  const signPanel = {
    name: "sign_texture_panel",
    uuid: crypto.randomUUID(),
    from: [0.71, 1.33, 0.268],
    to: [1.45, 1.77, 0.269],
    origin: [0, 0, 0],
    color: 12,
    material_key: "sign_texture_panel",
    codex_plane: { axis: "z_min" },
    faces: {
      north: { uv: [0, 0, 128, 64], texture: 1 },
      east: { uv: [0, 0, 128, 64], texture: 1 },
      south: { uv: [0, 0, 128, 64], texture: 1 },
      west: { uv: [0, 0, 128, 64], texture: 1 },
      up: { uv: [0, 0, 128, 64], texture: 1 },
      down: { uv: [0, 0, 128, 64], texture: 1 }
    }
  };
  model.elements.push(signPanel);
  model.outliner = model.elements.map((element) => element.uuid);
  model.textures.push({
    path: "textures/no_droids_sign_panel_v1.png",
    name: "no_droids_sign_panel_v1",
    folder: "",
    namespace: "",
    id: "1",
    particle: false,
    render_mode: "default",
    visible: true,
    mode: "bitmap",
    saved: true,
    uuid: crypto.randomUUID(),
    source: "textures/no_droids_sign_panel_v1.png"
  });
  return model;
}

const texturePath = path.join(OUT_TEXTURES, "no_droids_sign_panel_v1.png");
savePng(drawNoDroidsTexture(), texturePath);

const model = makeCandidateModel();
const bbmodelPath = path.join(OUT_BB, "blockbench_cantina_sign_texture_v1.bbmodel");
fs.writeFileSync(bbmodelPath, `${JSON.stringify(model, null, "\t")}\n`);

fs.writeFileSync(path.join(OUT_ROOT, "blockbench_manifest.json"), `${JSON.stringify({
  pack_id: "blockbench_cantina_sign_texture_v1",
  display_name: "Blockbench Cantina Sign Texture v1",
  generated_at: new Date().toISOString(),
  source_baseline: path.relative(PROJECT_ROOT, BASELINE).replaceAll("\\", "/"),
  changed_variable: "no-droids sign panel texture only",
  assets: [{
    id: "blockbench_cantina_sign_texture_v1",
    blockbench_path: path.relative(PROJECT_ROOT, bbmodelPath).replaceAll("\\", "/"),
    texture_path: path.relative(PROJECT_ROOT, texturePath).replaceAll("\\", "/")
  }]
}, null, 2)}\n`);

const review = [
  "# Blockbench Cantina Sign Texture v1 Source Review",
  "",
  `Generated: ${new Date().toISOString()}`,
  "Generator: `docs/gpt/asset_factory/scripts/cantina_sign_texture_pass.mjs`",
  "",
  "## Controlled Change",
  "",
  "Baseline: `generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md`",
  "",
  "Changed variable: no-droids sign workflow only.",
  "",
  "The candidate removes only the cube pictogram/slash elements and adds one original pixel-texture sign panel. The entrance geometry, detector, wall, steps, palette, and scale stay unchanged.",
  "",
  "## Source Files",
  "",
  "- `blockbench/blockbench_cantina_sign_texture_v1.bbmodel`",
  "- `blockbench/textures/no_droids_sign_panel_v1.png`",
  "",
  "## Texture",
  "",
  "![No droids sign texture](blockbench/textures/no_droids_sign_panel_v1.png)",
  "",
  "## Source Boundary",
  "",
  "The texture is an original blockcraft pictogram: a generic service-droid shape with a red prohibition mark. It does not trace official signage, logos, fan art, or exact protected iconography.",
  "",
  "## Next",
  "",
  "Convert to GLB with the texture-aware Blender adapter, validate, and run a Godot camera comparison against the cube-only sign baseline."
];

fs.writeFileSync(path.join(OUT_ROOT, "REVIEW.md"), `${review.join("\n")}\n`);

console.log(`Generated Cantina sign texture candidate at ${path.relative(PROJECT_ROOT, OUT_ROOT)}`);
