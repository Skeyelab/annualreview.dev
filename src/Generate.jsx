import React, { useState, useEffect } from "react";
import "./Generate.css";

const DEFAULT_START = new Date();
DEFAULT_START.setFullYear(DEFAULT_START.getFullYear() - 1);
const DEFAULT_END = new Date();
const toYMD = (d) => d.toISOString().slice(0, 10);

function buildMarkdown(result) {
  const lines = [];
  if (result.themes?.themes?.length) {
    lines.push("## Themes\n");
    for (const t of result.themes.themes) {
      lines.push(`### ${t.theme_name || t.theme_id}\n`);
      if (t.one_liner) lines.push(`${t.one_liner}\n`);
      if (t.why_it_matters) lines.push(`${t.why_it_matters}\n`);
    }
  }
  if (result.bullets?.top_10_bullets_overall?.length) {
    lines.push("\n## Top impact bullets\n");
    for (const b of result.bullets.top_10_bullets_overall) {
      const text = typeof b === "string" ? b : (b.bullet || b.text || JSON.stringify(b));
      lines.push(`- ${text}\n`);
    }
  }
  if (result.stories?.stories?.length) {
    lines.push("\n## STAR stories\n");
    for (const s of result.stories.stories) {
      lines.push(`### ${s.title || "Story"}\n`);
      if (s.situation) lines.push(`**Situation:** ${s.situation}\n`);
      if (s.task) lines.push(`**Task:** ${s.task}\n`);
      if (s.action) lines.push(`**Action:** ${s.action}\n`);
      if (s.result) lines.push(`**Result:** ${s.result}\n`);
    }
  }
  if (result.self_eval?.sections) {
    lines.push("\n## Self-evaluation\n");
    for (const [key, section] of Object.entries(result.self_eval.sections)) {
      const text = section?.text || (typeof section === "string" ? section : "");
      if (text) lines.push(`### ${key}\n\n${text}\n`);
    }
  }
  return lines.join("\n");
}

function EvidenceAppendix({ themes, contributions }) {
  if (!themes?.themes?.length && !contributions?.length) return null;
  const byTheme = [];
  if (themes?.themes?.length) {
    for (const t of themes.themes) {
      const links = (t.anchor_evidence || []).map((a) => ({ url: a.url, title: a.title || a.id }));
      if (links.length) byTheme.push({ name: t.theme_name || t.theme_id, links });
    }
  }
  const fallbackLinks = (contributions || []).slice(0, 20).map((c) => ({ url: c.url, title: c.title || c.id }));
  if (byTheme.length === 0 && fallbackLinks.length === 0) return null;
  return (
    <section className="generate-section">
      <h3>Evidence appendix</h3>
      {byTheme.length > 0 ? (
        <ul className="generate-appendix-list">
          {byTheme.map((g) => (
            <li key={g.name}>
              <strong>{g.name}</strong>
              <ul>
                {g.links.map((l) => (
                  <li key={l.url}>
                    <a href={l.url} target="_blank" rel="noopener noreferrer">{l.title || l.url}</a>
                  </li>
                ))}
              </ul>
            </li>
          ))}
        </ul>
      ) : (
        <ul className="generate-appendix-list">
          {fallbackLinks.map((l) => (
            <li key={l.url}>
              <a href={l.url} target="_blank" rel="noopener noreferrer">{l.title || l.url}</a>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function Generate() {
  const [evidenceText, setEvidenceText] = useState("");
  const [evidenceUsed, setEvidenceUsed] = useState(null);
  const [loading, setLoading] = useState(false);
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [connected, setConnected] = useState(false);
  const [importStart, setImportStart] = useState(toYMD(DEFAULT_START));
  const [importEnd, setImportEnd] = useState(toYMD(DEFAULT_END));

  useEffect(() => {
    const p = fetch("/api/me");
    if (!p || typeof p.then !== "function") {
      setConnected(false);
      return;
    }
    p.then((r) => r?.json?.() ?? { connected: false })
      .then((data) => setConnected(data.connected === true))
      .catch(() => setConnected(false));
  }, []);

  const handleGenerate = async () => {
    let evidence;
    try {
      evidence = JSON.parse(evidenceText);
    } catch {
      setError("Invalid JSON. Paste or upload a valid evidence.json.");
      return;
    }
    if (!evidence.timeframe?.start_date || !evidence.timeframe?.end_date || !Array.isArray(evidence.contributions)) {
      setError("Evidence must have timeframe.start_date, timeframe.end_date, and contributions array.");
      return;
    }
    setError(null);
    setLoading(true);
    setResult(null);
    try {
      const res = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(evidence),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Generate failed");
      setEvidenceUsed(evidence);
      setResult(data);
    } catch (e) {
      setError(e.message || "Pipeline failed. Is OPENAI_API_KEY set?");
    } finally {
      setLoading(false);
    }
  };

  const handleImport = async () => {
    setError(null);
    setImporting(true);
    try {
      const res = await fetch("/api/import", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ start_date: importStart, end_date: importEnd }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Import failed");
      setEvidenceText(JSON.stringify(data, null, 2));
    } catch (e) {
      setError(e.message || "Import failed");
    } finally {
      setImporting(false);
    }
  };

  const handleFile = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const r = new FileReader();
    r.onload = () => { setEvidenceText(r.result); setError(null); };
    r.readAsText(file);
  };

  const loadSample = async () => {
    try {
      const res = await fetch("/sample-evidence.json");
      const data = await res.json();
      setEvidenceText(JSON.stringify(data, null, 2));
      setError(null);
    } catch {
      setError("Could not load sample.");
    }
  };

  const downloadMarkdown = () => {
    if (!result) return;
    const blob = new Blob([buildMarkdown(result)], { type: "text/markdown" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "annual-review.md";
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const downloadJson = () => {
    if (!result) return;
    const blob = new Blob([JSON.stringify(result, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "annual-review.json";
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const urlParams = typeof window !== "undefined" ? new URLSearchParams(window.location.search) : null;
  const oauthError = urlParams?.get("error");

  return (
    <div className="generate">
      <header className="generate-header">
        <a href="/" className="generate-logo">
          <span className="generate-logo-icon">⟡</span>
          AnnualReview.dev
        </a>
        <a href="/" className="generate-back">← Back</a>
      </header>

      <main className="generate-main">
        <h1 className="generate-title">Generate review</h1>
        <p className="generate-lead">
          Import from GitHub or paste evidence JSON below. Must include <code>timeframe</code> and <code>contributions</code>.
        </p>

        {connected ? (
          <div className="generate-import-block">
            <label className="generate-import-label">
              <span>From</span>
              <input
                type="date"
                value={importStart}
                onChange={(e) => setImportStart(e.target.value)}
                className="generate-import-date"
              />
            </label>
            <label className="generate-import-label">
              <span>To</span>
              <input
                type="date"
                value={importEnd}
                onChange={(e) => setImportEnd(e.target.value)}
                className="generate-import-date"
              />
            </label>
            <button type="button" className="generate-import-btn" onClick={handleImport} disabled={importing}>
              {importing ? "Importing…" : "Import from GitHub"}
            </button>
          </div>
        ) : (
          <p className="generate-connect">
            <a href="/api/auth/github">Connect GitHub</a> to import your PRs and reviews, then generate.
          </p>
        )}

        {oauthError && (
          <p className="generate-error">
            OAuth: {oauthError}. Check server env (GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET) or try again.
          </p>
        )}

        <div className="generate-input-row">
          <label className="generate-file-label">
            Upload evidence.json
            <input type="file" accept=".json,application/json" onChange={handleFile} className="generate-file-input" />
          </label>
          <button type="button" className="generate-sample-btn" onClick={loadSample}>Try sample</button>
        </div>
        <textarea
          className="generate-textarea"
          placeholder='{"timeframe": {"start_date": "2025-01-01", "end_date": "2025-12-31"}, "contributions": [...]}'
          value={evidenceText}
          onChange={(e) => { setEvidenceText(e.target.value); setError(null); }}
          rows={8}
        />

        {error && <p className="generate-error">{error}</p>}

        <button type="button" className="generate-btn" onClick={handleGenerate} disabled={loading}>
          {loading ? "Generating…" : "Generate review"}
        </button>

        {result && (
          <div className="generate-result">
            <div className="generate-result-actions">
              <h2>Your review</h2>
              <div className="generate-export-btns">
                <button type="button" className="generate-copy" onClick={downloadMarkdown}>Download Markdown</button>
                <button type="button" className="generate-copy" onClick={downloadJson}>Download JSON</button>
              </div>
            </div>
            <Section title="Themes" data={result.themes} />
            <Section title="Bullets" data={result.bullets} />
            <Section title="STAR stories" data={result.stories} />
            <Section title="Self-eval sections" data={result.self_eval} />
            <EvidenceAppendix themes={result.themes} contributions={evidenceUsed?.contributions} />
          </div>
        )}
      </main>
    </div>
  );
}

function Section({ title, data }) {
  const text = JSON.stringify(data, null, 2);
  return (
    <section className="generate-section">
      <div className="generate-section-head">
        <h3>{title}</h3>
        <button type="button" className="generate-copy" onClick={() => navigator.clipboard.writeText(text)}>Copy</button>
      </div>
      <pre className="generate-pre">{text}</pre>
    </section>
  );
}
