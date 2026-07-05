import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import crypto from "node:crypto";

const PROJECT_ROOT = process.cwd();
const DEFAULT_SPEC = "docs/gpt/asset_factory/specs/blockbench_cubecraft_v0.json";
const specPath = path.resolve(PROJECT_ROOT, process.argv[2] ?? DEFAULT_SPEC);
const spec = JSON.parse(fs.readFileSync(specPath, "utf8").replace(/^\uFEFF/, ""));

const outRoot = path.resolve(PROJECT_ROOT, "docs/gpt/asset_factory", spec.output_folder ?? `generated/${spec.pack_id}`);
const blockbenchDir = path.join(outRoot, "blockbench");
const textureDir = path.join(blockbenchDir, "textures");
const previewDir = path.join(outRoot, "previews");

fs.mkdirSync(blockbenchDir, { recursive: true });
fs.mkdirSync(textureDir, { recursive: true });
fs.mkdirSync(previewDir, { recursive: true });

const palette = spec.palette ?? {};

function clamp(v, lo = 0, hi = 255) {
  return Math.max(lo, Math.min(hi, Math.round(v)));
}

function hexToRgb(hex) {
  const clean = String(hex).replace("#", "");
  const expanded = clean.length === 3
    ? clean.split("").map((c) => c + c).join("")
    : clean;
  return {
    r: parseInt(expanded.slice(0, 2), 16),
    g: parseInt(expanded.slice(2, 4), 16),
    b: parseInt(expanded.slice(4, 6), 16),
    a: 255
  };
}

function shadeColor(rgb, factor) {
  return {
    r: clamp(rgb.r * factor),
    g: clamp(rgb.g * factor),
    b: clamp(rgb.b * factor),
    a: rgb.a
  };
}

function materialColor(key) {
  return hexToRgb(palette[key] ?? "#d0d0d0");
}

function pos(cube) {
  return cube.position ?? [0, 0, 0];
}

function size(cube) {
  return cube.size ?? [1, 1, 1];
}

function cubeBounds(cube) {
  const p = pos(cube);
  const s = size(cube);
  return {
    x0: p[0] - s[0] / 2,
    x1: p[0] + s[0] / 2,
    y0: p[1] - s[1] / 2,
    y1: p[1] + s[1] / 2,
    z0: p[2] - s[2] / 2,
    z1: p[2] + s[2] / 2
  };
}

function createCanvas(width, height, color = { r: 149, g: 171, b: 185, a: 255 }) {
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

function drawLine(canvas, a, b, color) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const steps = Math.max(Math.abs(dx), Math.abs(dy), 1);
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    setPixel(canvas, a.x + dx * t, a.y + dy * t, color);
  }
}

function fillPolygon(canvas, points, color) {
  const minY = Math.floor(Math.min(...points.map((p) => p.y)));
  const maxY = Math.ceil(Math.max(...points.map((p) => p.y)));
  for (let y = minY; y <= maxY; y++) {
    const scanY = y + 0.5;
    const xs = [];
    for (let i = 0; i < points.length; i++) {
      const a = points[i];
      const b = points[(i + 1) % points.length];
      if ((a.y <= scanY && b.y > scanY) || (b.y <= scanY && a.y > scanY)) {
        const t = (scanY - a.y) / (b.y - a.y);
        xs.push(a.x + t * (b.x - a.x));
      }
    }
    xs.sort((a, b) => a - b);
    for (let i = 0; i < xs.length; i += 2) {
      const x0 = Math.floor(xs[i]);
      const x1 = Math.ceil(xs[i + 1]);
      for (let x = x0; x <= x1; x++) setPixel(canvas, x, y, color);
    }
  }
}

function strokePolygon(canvas, points, color) {
  for (let i = 0; i < points.length; i++) {
    drawLine(canvas, points[i], points[(i + 1) % points.length], color);
  }
}

function project(v, transform) {
  return {
    x: (v.x - v.z) * transform.scale + transform.cx,
    y: (v.x + v.z) * transform.scale * 0.5 - v.y * transform.scale + transform.cy
  };
}

function projectedExtents(asset, width, height) {
  const vertices = [];
  for (const cube of asset.cubes) {
    const b = cubeBounds(cube);
    for (const x of [b.x0, b.x1]) {
      for (const y of [b.y0, b.y1]) {
        for (const z of [b.z0, b.z1]) vertices.push({ x, y, z });
      }
    }
  }
  const raw = vertices.map((v) => ({ x: v.x - v.z, y: (v.x + v.z) * 0.5 - v.y }));
  const minX = Math.min(...raw.map((p) => p.x));
  const maxX = Math.max(...raw.map((p) => p.x));
  const minY = Math.min(...raw.map((p) => p.y));
  const maxY = Math.max(...raw.map((p) => p.y));
  const margin = 44;
  const scale = Math.min((width - margin * 2) / Math.max(0.01, maxX - minX), (height - margin * 2) / Math.max(0.01, maxY - minY));
  return {
    scale,
    cx: width / 2 - (minX + maxX) * 0.5 * scale,
    cy: height / 2 - (minY + maxY) * 0.5 * scale + 12
  };
}

function facesForCube(cube) {
  const b = cubeBounds(cube);
  const rgb = materialColor(cube.material);
  const edge = shadeColor(rgb, 0.42);
  return [
    {
      depth: b.x0 + b.z0 + b.y1 * 0.05,
      color: shadeColor(rgb, 1.2),
      edge,
      verts: [
        { x: b.x0, y: b.y1, z: b.z0 },
        { x: b.x1, y: b.y1, z: b.z0 },
        { x: b.x1, y: b.y1, z: b.z1 },
        { x: b.x0, y: b.y1, z: b.z1 }
      ]
    },
    {
      depth: b.x1 + b.z0 + b.y0 * 0.05,
      color: shadeColor(rgb, 0.86),
      edge,
      verts: [
        { x: b.x1, y: b.y0, z: b.z0 },
        { x: b.x1, y: b.y0, z: b.z1 },
        { x: b.x1, y: b.y1, z: b.z1 },
        { x: b.x1, y: b.y1, z: b.z0 }
      ]
    },
    {
      depth: b.x0 + b.z1 + b.y0 * 0.05,
      color: shadeColor(rgb, 0.72),
      edge,
      verts: [
        { x: b.x0, y: b.y0, z: b.z1 },
        { x: b.x1, y: b.y0, z: b.z1 },
        { x: b.x1, y: b.y1, z: b.z1 },
        { x: b.x0, y: b.y1, z: b.z1 }
      ]
    }
  ];
}

function renderAsset(asset, width = 720, height = 520) {
  const canvas = createCanvas(width, height, hexToRgb(spec.preview_background ?? "#96acba"));
  const transform = projectedExtents(asset, width, height);
  const faces = [];
  for (const cube of asset.cubes) faces.push(...facesForCube(cube));
  faces.sort((a, b) => a.depth - b.depth);
  for (const face of faces) {
    const points = face.verts.map((v) => project(v, transform));
    fillPolygon(canvas, points, face.color);
    strokePolygon(canvas, points, face.edge);
  }
  return canvas;
}

function paste(target, source, x, y) {
  for (let yy = 0; yy < source.height; yy++) {
    for (let xx = 0; xx < source.width; xx++) {
      const src = (yy * source.width + xx) * 4;
      const dstX = x + xx;
      const dstY = y + yy;
      if (dstX < 0 || dstY < 0 || dstX >= target.width || dstY >= target.height) continue;
      const dst = (dstY * target.width + dstX) * 4;
      target.data[dst + 0] = source.data[src + 0];
      target.data[dst + 1] = source.data[src + 1];
      target.data[dst + 2] = source.data[src + 2];
      target.data[dst + 3] = source.data[src + 3];
    }
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
  header[10] = 0;
  header[11] = 0;
  header[12] = 0;
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

function textureAtlas(materials, filePath) {
  const cell = 16;
  const cols = Math.ceil(Math.sqrt(materials.length));
  const rows = Math.ceil(materials.length / cols);
  const canvas = createCanvas(cols * cell, rows * cell, { r: 0, g: 0, b: 0, a: 0 });
  materials.forEach((mat, i) => {
    const rgb = materialColor(mat);
    fillRect(canvas, (i % cols) * cell, Math.floor(i / cols) * cell, cell, cell, rgb);
  });
  savePng(canvas, filePath);
  return { cell, cols, rows, width: cols * cell, height: rows * cell };
}

function uvForMaterial(mat, materials, atlas) {
  const i = materials.indexOf(mat);
  const x = (i % atlas.cols) * atlas.cell;
  const y = Math.floor(i / atlas.cols) * atlas.cell;
  return [x, y, x + atlas.cell, y + atlas.cell];
}

function blockbenchModel(asset) {
  const materials = [...new Set(asset.cubes.map((cube) => cube.material))];
  const texturePath = path.join(textureDir, `${asset.id}_palette.png`);
  const atlas = textureAtlas(materials, texturePath);
  const textureRel = `textures/${asset.id}_palette.png`;
  const elements = asset.cubes.map((cube, i) => {
    const b = cubeBounds(cube);
    const uv = uvForMaterial(cube.material, materials, atlas);
    const face = { uv, texture: 0 };
    return {
      name: cube.name ?? `cube_${i}`,
      uuid: crypto.randomUUID(),
      from: [b.x0, b.y0, b.z0],
      to: [b.x1, b.y1, b.z1],
      origin: [0, 0, 0],
      color: Math.max(0, materials.indexOf(cube.material)),
      material_key: cube.material,
      faces: {
        north: face,
        east: face,
        south: face,
        west: face,
        up: face,
        down: face
      }
    };
  });
  return {
    meta: {
      format_version: "4.10",
      model_format: "free",
      box_uv: false
    },
    codex_source: {
      schema: spec.schema,
      pack_id: spec.pack_id,
      asset_id: asset.id,
      generator: "docs/gpt/asset_factory/scripts/blockbench_cubecraft_factory.mjs"
    },
    codex_palette: palette,
    name: asset.display_name ?? asset.id,
    model_identifier: asset.id,
    visible_box: [1, 1, 0],
    variable_placeholders: "",
    resolution: {
      width: atlas.width,
      height: atlas.height
    },
    elements,
    outliner: elements.map((el) => el.uuid),
    textures: [
      {
        path: textureRel,
        name: `${asset.id}_palette`,
        folder: "",
        namespace: "",
        id: "0",
        particle: false,
        render_mode: "default",
        visible: true,
        mode: "bitmap",
        saved: true,
        uuid: crypto.randomUUID(),
        source: textureRel
      }
    ]
  };
}

const manifest = {
  pack_id: spec.pack_id,
  display_name: spec.display_name,
  source_spec: path.relative(PROJECT_ROOT, specPath).replaceAll("\\", "/"),
  generated_at: new Date().toISOString(),
  assets: []
};

const previews = [];
for (const asset of spec.assets) {
  const bbmodel = blockbenchModel(asset);
  const bbmodelPath = path.join(blockbenchDir, `${asset.id}.bbmodel`);
  fs.writeFileSync(bbmodelPath, `${JSON.stringify(bbmodel, null, "\t")}\n`);

  const preview = renderAsset(asset, 720, 520);
  const previewPath = path.join(previewDir, `${asset.id}.png`);
  savePng(preview, previewPath);
  previews.push(preview);

  manifest.assets.push({
    id: asset.id,
    display_name: asset.display_name,
    category: asset.category,
    gameplay_role: asset.gameplay_role,
    blockbench_path: path.relative(PROJECT_ROOT, bbmodelPath).replaceAll("\\", "/"),
    preview_path: path.relative(PROJECT_ROOT, previewPath).replaceAll("\\", "/")
  });
}

const tileW = 360;
const tileH = 260;
const cols = Math.min(3, Math.max(1, spec.assets.length));
const rows = Math.ceil(spec.assets.length / cols);
const sheet = createCanvas(cols * tileW, rows * tileH, hexToRgb(spec.preview_background ?? "#96acba"));
previews.forEach((preview, i) => {
  const small = renderAsset(spec.assets[i], tileW, tileH);
  paste(sheet, small, (i % cols) * tileW, Math.floor(i / cols) * tileH);
});
const sheetPath = path.join(previewDir, "contact_sheet.png");
savePng(sheet, sheetPath);
manifest.contact_sheet = path.relative(PROJECT_ROOT, sheetPath).replaceAll("\\", "/");

const manifestPath = path.join(outRoot, "blockbench_manifest.json");
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, "\t")}\n`);

const reviewLines = [
  `# ${spec.display_name} Review Board`,
  "",
  `Generated: ${manifest.generated_at}`,
  "Generator: `docs/gpt/asset_factory/scripts/blockbench_cubecraft_factory.mjs`",
  "",
  "## What This Is",
  "",
  "This pass changes the authoring target: it generates Blockbench `.bbmodel` files plus PNG previews from the same cube data. The intent is to test a Cubecraft/Minecraft-like workflow rather than another Godot-first primitive pack.",
  "",
  "## Contact Sheet",
  "",
  "![Contact sheet](previews/contact_sheet.png)",
  "",
  "## Assets",
  "",
  "| Asset | Role | Blockbench Source | Preview |",
  "| --- | --- | --- | --- |",
  ...manifest.assets.map((asset) => {
    const bb = path.relative(outRoot, path.resolve(PROJECT_ROOT, asset.blockbench_path)).replaceAll("\\", "/");
    const img = path.relative(outRoot, path.resolve(PROJECT_ROOT, asset.preview_path)).replaceAll("\\", "/");
    return `| ${asset.display_name} | ${asset.gameplay_role} | [bbmodel](${bb}) | ![${asset.display_name}](${img}) |`;
  }),
  "",
  "## Review Tags",
  "",
  "- `open-in-blockbench`: check/edit the source model in Blockbench.",
  "- `export-gltf-candidate`: good enough to export from Blockbench for Godot import testing.",
  "- `needs-cubecraft-pass`: proportions/texture panels need stronger Cubecraft charm.",
  "- `fallback-to-godot-spec`: the Godot primitive lane is faster/better for this asset."
];

fs.writeFileSync(path.join(outRoot, "REVIEW.md"), `${reviewLines.join("\n")}\n`);

console.log(`Generated ${manifest.assets.length} Blockbench models at ${path.relative(PROJECT_ROOT, outRoot)}`);
