// Converts the browser game's packed models (models/*.js -> WS_MODELS) into .glb files Godot imports directly.
// usage: node ws2glb.js <models dir> <tex root> <out dir> NAME[=outname] ...
const fs = require('fs'), path = require('path');
global.window = global;
const [, , mdir, texRoot, outDir, ...names] = process.argv;
for (const f of fs.readdirSync(mdir)) if (f.endsWith('.js')) { try { require(path.resolve(mdir, f)); } catch (e) { } }
fs.mkdirSync(outDir, { recursive: true });

const u16 = s => { const b = Buffer.from(s, 'base64'); return new Uint16Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.length)); };
const u32 = s => { const b = Buffer.from(s, 'base64'); return new Uint32Array(b.buffer.slice(b.byteOffset, b.byteOffset + b.length)); };

function convert(name, out) {
  const D = WS_MODELS[name]; if (!D) { console.error('missing', name); return; }
  const q = u16(D.pos), nv = q.length / 3, pos = new Float32Array(q.length);
  for (let i = 0; i < q.length; i++) { const k = i % 3; pos[i] = D.min[k] + q[i] / 65535 * D.ext[k]; }
  let idx = D.i32 ? u32(D.idx) : u16(D.idx); idx = new Uint32Array(idx);
  let nrm = null;
  if (D.nrm) { const b = Buffer.from(D.nrm, 'base64'); nrm = new Float32Array(b.length); for (let i = 0; i < b.length; i++) { const c = b[i]; nrm[i] = (c > 127 ? c - 256 : c) / 127; }
    for (let i = 0; i < nv; i++) { const l = Math.hypot(nrm[3*i], nrm[3*i+1], nrm[3*i+2]) || 1; nrm[3*i] /= l; nrm[3*i+1] /= l; nrm[3*i+2] /= l; } }
  else { // smooth normals from faces
    nrm = new Float32Array(nv * 3);
    for (let t = 0; t < idx.length; t += 3) { const a = idx[t], b = idx[t+1], c = idx[t+2];
      const ax = pos[3*b]-pos[3*a], ay = pos[3*b+1]-pos[3*a+1], az = pos[3*b+2]-pos[3*a+2], bx = pos[3*c]-pos[3*a], by = pos[3*c+1]-pos[3*a+1], bz = pos[3*c+2]-pos[3*a+2];
      const nx = ay*bz-az*by, ny = az*bx-ax*bz, nz = ax*by-ay*bx; for (const v of [a,b,c]) { nrm[3*v]+=nx; nrm[3*v+1]+=ny; nrm[3*v+2]+=nz; } }
    for (let i = 0; i < nv; i++) { const l = Math.hypot(nrm[3*i], nrm[3*i+1], nrm[3*i+2]) || 1; nrm[3*i] /= l; nrm[3*i+1] /= l; nrm[3*i+2] /= l; }
  }
  let uv = null;
  if (D.uv) { const uq = u16(D.uv); uv = new Float32Array(uq.length); for (let i = 0; i < uq.length; i++) uv[i] = D.uvMin[i & 1] + uq[i] / 65535 * D.uvExt[i & 1];
  }
  const rd = t => t && fs.existsSync(path.join(texRoot, t)) ? fs.readFileSync(path.join(texRoot, t)) : null;
  const tex = rd(D.tex), ntex = rd(D.ntex), mrtex = rd(D.mrtex);
  let vcol = null;
  if (D.vcol) { const b = Buffer.from(D.vcol, 'base64'); vcol = new Float32Array(nv * 4); for (let i = 0; i < nv; i++) { vcol[4*i] = b[3*i] / 255; vcol[4*i+1] = b[3*i+1] / 255; vcol[4*i+2] = b[3*i+2] / 255; vcol[4*i+3] = 1; } }

  // pack the binary buffer
  const parts = [], views = [], acc = []; let off = 0;
  const add = (buf, target) => { const pad = (4 - (buf.length % 4)) % 4; views.push({ buffer: 0, byteOffset: off, byteLength: buf.length, ...(target ? { target } : {}) }); parts.push(buf, Buffer.alloc(pad)); off += buf.length + pad; return views.length - 1; };
  const mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9]; for (let i = 0; i < nv; i++) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], pos[3*i+k]); mx[k] = Math.max(mx[k], pos[3*i+k]); }
  acc.push({ bufferView: add(Buffer.from(pos.buffer), 34962), componentType: 5126, count: nv, type: 'VEC3', min: mn, max: mx });
  acc.push({ bufferView: add(Buffer.from(nrm.buffer), 34962), componentType: 5126, count: nv, type: 'VEC3' });
  if (uv) acc.push({ bufferView: add(Buffer.from(uv.buffer), 34962), componentType: 5126, count: nv, type: 'VEC2' });
  const attrs = { POSITION: 0, NORMAL: 1, ...(uv ? { TEXCOORD_0: 2 } : {}) };
  if (vcol) { acc.push({ bufferView: add(Buffer.from(vcol.buffer), 34962), componentType: 5126, count: nv, type: 'VEC4' }); attrs.COLOR_0 = acc.length - 1; }
  const prims = []; let st = 0;
  (D.counts || [idx.length / 3]).forEach((c) => { if (!c) return; const sub = idx.slice(st * 3, (st + c) * 3); st += c;
    acc.push({ bufferView: add(Buffer.from(sub.buffer), 34963), componentType: 5125, count: sub.length, type: 'SCALAR' });
    prims.push({ attributes: attrs, indices: acc.length - 1, material: 0 }); });
  const gltf = { asset: { version: '2.0', generator: 'ws2glb' }, scene: 0, scenes: [{ nodes: [0] }], nodes: [{ mesh: 0, name: out }],
    meshes: [{ name: out, primitives: prims }],
    materials: [{ name: out + '_mat', pbrMetallicRoughness: { metallicFactor: mrtex ? 1.0 : 0.1, roughnessFactor: mrtex ? 1.0 : 0.75 }, doubleSided: true }],
    accessors: acc, bufferViews: views, buffers: [] };
  gltf.images = []; gltf.textures = []; gltf.samplers = [{ magFilter: 9729, minFilter: 9987 }];
  const M = gltf.materials[0];
  const addImg = (buf, name) => { const v = add(buf); gltf.images.push({ bufferView: v, mimeType: name.endsWith('.png') ? 'image/png' : 'image/jpeg' }); gltf.textures.push({ source: gltf.images.length - 1, sampler: 0 }); return gltf.textures.length - 1; };
  if (tex) { M.pbrMetallicRoughness.baseColorTexture = { index: addImg(tex, D.tex) }; if (D.tex.endsWith('.png')) { M.alphaMode = 'MASK'; M.alphaCutoff = 0.4; } }
  else if (!vcol) M.pbrMetallicRoughness.baseColorFactor = [0.5, 0.5, 0.5, 1];
  if (ntex) M.normalTexture = { index: addImg(ntex, D.ntex) };
  if (mrtex) M.pbrMetallicRoughness.metallicRoughnessTexture = { index: addImg(mrtex, D.mrtex) };
  if (!gltf.images.length) { delete gltf.images; delete gltf.textures; delete gltf.samplers; }
  const bin = Buffer.concat(parts); gltf.buffers.push({ byteLength: bin.length });
  let js = Buffer.from(JSON.stringify(gltf)); js = Buffer.concat([js, Buffer.alloc((4 - js.length % 4) % 4, 0x20)]);
  const hdr = Buffer.alloc(12); hdr.writeUInt32LE(0x46546C67, 0); hdr.writeUInt32LE(2, 4); hdr.writeUInt32LE(12 + 8 + js.length + 8 + bin.length, 8);
  const c0 = Buffer.alloc(8); c0.writeUInt32LE(js.length, 0); c0.writeUInt32LE(0x4E4F534A, 4);
  const c1 = Buffer.alloc(8); c1.writeUInt32LE(bin.length, 0); c1.writeUInt32LE(0x004E4942, 4);
  fs.writeFileSync(path.join(outDir, out + '.glb'), Buffer.concat([hdr, c0, js, c1, bin]));
  console.log(out, nv, 'verts', idx.length / 3, 'tris', 'bounds', mn.map(x=>x.toFixed(2)), mx.map(x=>x.toFixed(2)));
}
for (const n of names) { const [a, b] = n.split('='); convert(a, b || a.toLowerCase()); }
