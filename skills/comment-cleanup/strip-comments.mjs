#!/usr/bin/env node
// Strip comments from .ts/.tsx/.js/.mjs/.css files through the TypeScript
// parser (comment trivia ranges), not a regex. Keeps tool directives, licence
// headers and TODO/FIXME/HACK/XXX. Removes the `{}` a `{/* … */}` leaves behind.
// Refuses to write a file whose parse would gain errors.
//
// Usage: node strip-comments.mjs <file-list>     (one path per line, relative to cwd)
// Needs `typescript` resolvable from cwd (the repo's node_modules).

import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const ts = createRequire(path.join(process.cwd(), "package.json"))("typescript");

const KEEP =
  /^(eslint|@ts-|ts-|prettier|c8\b|v8\b|istanbul|@jsx|@license|@preserve|#region|#endregion|@vitest|webpack|@__PURE__|<reference|TODO\b|FIXME\b|HACK\b|XXX\b)/i;

const body = (text, r) =>
  text.slice(r.pos, r.end).replace(/^\/\/+/, "").replace(/^\/\*+/, "").replace(/\*\/$/, "").trim();

const kindOf = (f) =>
  f.endsWith(".tsx") ? ts.ScriptKind.TSX : f.endsWith(".ts") ? ts.ScriptKind.TS : ts.ScriptKind.JS;

function commentRanges(text, file) {
  const sf = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true, kindOf(file));
  const seen = new Map();
  const add = (ranges) => {
    for (const r of ranges ?? []) {
      if (seen.has(r.pos)) continue;
      if (r.pos === 0 && text.startsWith("#!")) continue;
      if (KEEP.test(body(text, r))) continue;
      seen.set(r.pos, r);
    }
  };
  const walk = (n) => {
    add(ts.getLeadingCommentRanges(text, n.pos));
    add(ts.getTrailingCommentRanges(text, n.end));
    for (const c of n.getChildren(sf)) walk(c);
  };
  walk(sf);
  return [...seen.values()].sort((a, b) => a.pos - b.pos);
}

const lineStart = (t, p) => {
  let i = p;
  while (i > 0 && t[i - 1] !== "\n") i--;
  return i;
};
const lineEnd = (t, p) => {
  let i = p;
  while (i < t.length && t[i] !== "\n") i++;
  return i;
};
const blank = (s) => /^[ \t]*$/.test(s);

// Delete a range; take the whole line when the comment owns it, else the
// comment plus the whitespace in front of it.
function cutRanges(text, ranges) {
  const cuts = ranges.map((r) => {
    let s = r.pos, e = r.end;
    const ls = lineStart(text, s), le = lineEnd(text, e);
    if (blank(text.slice(ls, s)) && blank(text.slice(e, le))) return [ls, le < text.length ? le + 1 : le];
    while (s > 0 && /[ \t]/.test(text[s - 1])) s--;
    if (blank(text.slice(e, le))) e = le;
    return [s, e];
  });
  let out = text;
  for (let i = cuts.length - 1; i >= 0; i--) out = out.slice(0, cuts[i][0]) + out.slice(cuts[i][1]);
  return out;
}

function dropEmptyJsxExpressions(text, file) {
  const sf = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true, kindOf(file));
  const del = [];
  const walk = (n) => {
    if (ts.isJsxExpression(n) && !n.expression) del.push([n.getStart(sf), n.getEnd()]);
    n.forEachChild(walk);
  };
  sf.forEachChild(walk);
  let out = text;
  for (let i = del.length - 1; i >= 0; i--) {
    let [s, e] = del[i];
    const ls = lineStart(out, s), le = lineEnd(out, e);
    if (blank(out.slice(ls, s)) && blank(out.slice(e, le))) [s, e] = [ls, le < out.length ? le + 1 : le];
    out = out.slice(0, s) + out.slice(e);
  }
  return out;
}

function stripCss(text) {
  let out = "", i = 0, q = null;
  while (i < text.length) {
    const c = text[i];
    if (q) {
      out += c;
      if (c === "\\") { out += text[i + 1] ?? ""; i += 2; continue; }
      if (c === q) q = null;
      i++; continue;
    }
    if (c === '"' || c === "'") { q = c; out += c; i++; continue; }
    if (c === "/" && text[i + 1] === "*") {
      const end = text.indexOf("*/", i + 2);
      const stop = end === -1 ? text.length : end + 2;
      if (KEEP.test(text.slice(i + 2, stop - 2).trim())) { out += text.slice(i, stop); i = stop; continue; }
      const ls = lineStart(text, i), le = lineEnd(text, stop);
      if (blank(text.slice(ls, i)) && blank(text.slice(stop, le))) {
        out = out.slice(0, out.length - (i - ls));
        i = le < text.length ? le + 1 : le;
      } else {
        if (blank(text.slice(stop, le))) out = out.replace(/[ \t]+$/, "");
        i = stop;
      }
      continue;
    }
    out += c; i++;
  }
  return out;
}

const tidy = (t) => t.replace(/^\n+/, "").replace(/\n{3,}/g, "\n\n");

const listFile = process.argv[2];
if (!listFile) { console.error("usage: strip-comments.mjs <file-list>"); process.exit(2); }
const files = fs.readFileSync(listFile, "utf8").split("\n").filter(Boolean);

let changed = 0;
const refused = [];
for (const f of files) {
  if (!fs.existsSync(f)) continue;
  const before = fs.readFileSync(f, "utf8");
  let after;
  if (f.endsWith(".css")) after = stripCss(before);
  else {
    after = cutRanges(before, commentRanges(before, f));
    if (f.endsWith(".tsx")) after = dropEmptyJsxExpressions(after, f);
  }
  after = tidy(after);
  if (after === before) continue;
  if (!f.endsWith(".css")) {
    const errs = (t) => ts.createSourceFile(f, t, ts.ScriptTarget.Latest, true, kindOf(f)).parseDiagnostics.length;
    if (errs(after) > errs(before)) { refused.push(f); continue; }
  }
  fs.writeFileSync(f, after);
  changed++;
}
console.log(`stripped ${changed} of ${files.length} files`);
if (refused.length) { console.log("REFUSED (parse would break):\n" + refused.join("\n")); process.exit(1); }
