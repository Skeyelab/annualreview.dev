/**
 * @vitest-environment jsdom
 */
import React from "react";
import { describe, it, expect } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import NarrativeView, { shortEvidenceLabel } from "../src/NarrativeView.tsx";

const mockThemes = {
  themes: [
    { theme_id: "reliability", theme_name: "Platform Reliability" },
    { theme_id: "arch", theme_name: "Architecture" },
  ],
};

const mockBullets = {
  bullets_by_theme: [
    {
      theme_id: "reliability",
      bullets: [
        {
          text: "Improved webhook delivery success rate by adding retry logic.",
          evidence: [
            { id: "org/repo#412", url: "https://github.com/org/repo/pull/412" },
          ],
        },
      ],
    },
    {
      theme_id: "arch",
      bullets: [
        {
          text: "Led extraction of billing service from the monolith.",
          evidence: [
            { id: "org/repo#389", url: "https://github.com/org/repo/pull/389" },
            { id: "org/repo#401", url: "https://github.com/org/repo/pull/401" },
          ],
        },
      ],
    },
  ],
};

describe("shortEvidenceLabel", () => {
  it("extracts PR number from org/repo#123", () => {
    expect(shortEvidenceLabel("org/repo#412")).toBe("PR #412");
  });

  it("returns raw id when no # present", () => {
    expect(shortEvidenceLabel("some-id")).toBe("some-id");
  });

  it("returns hash suffix as-is for non-numeric fragments", () => {
    expect(shortEvidenceLabel("org/repo#abc")).toBe("#abc");
  });

  it("handles undefined/empty gracefully", () => {
    expect(shortEvidenceLabel(undefined)).toBe("ref");
    expect(shortEvidenceLabel("")).toBe("ref");
  });
});

describe("NarrativeView", () => {
  it("renders theme names as headings", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    expect(screen.getAllByText("Platform Reliability").length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText("Architecture").length).toBeGreaterThanOrEqual(1);
  });

  it("renders bullet text", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    expect(screen.getByText(/Improved webhook delivery/)).toBeInTheDocument();
    expect(screen.getByText(/Led extraction of billing/)).toBeInTheDocument();
  });

  it("renders evidence tags as links with short labels", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    const link412 = screen.getByRole("link", { name: "PR #412" });
    expect(link412).toHaveAttribute("href", "https://github.com/org/repo/pull/412");

    const link389 = screen.getByRole("link", { name: "PR #389" });
    expect(link389).toHaveAttribute("href", "https://github.com/org/repo/pull/389");
  });

  it("falls back to theme_id when theme name not found", () => {
    const bullets = {
      bullets_by_theme: [
        {
          theme_id: "unknown-theme",
          bullets: [{ text: "Some bullet.", evidence: [] }],
        },
      ],
    };
    render(<NarrativeView themes={mockThemes} bullets={bullets} />);
    expect(screen.getAllByText("unknown-theme").length).toBeGreaterThanOrEqual(1);
  });

  it("shows empty state when bullets_by_theme is empty", () => {
    render(<NarrativeView themes={mockThemes} bullets={{ bullets_by_theme: [] }} />);
    expect(screen.getByText(/no impact bullets/i)).toBeInTheDocument();
  });

  it("shows empty state when bullets prop is undefined", () => {
    render(<NarrativeView themes={mockThemes} bullets={undefined} />);
    expect(screen.getByText(/no impact bullets/i)).toBeInTheDocument();
  });

  it("shows empty state when themes and bullets are both undefined", () => {
    render(<NarrativeView themes={undefined} bullets={undefined} />);
    expect(screen.getByText(/no impact bullets/i)).toBeInTheDocument();
  });

  // ── Toggle behavior ──

  it("defaults to narrative view, not JSON", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    expect(screen.getAllByText("Platform Reliability").length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByText(/"theme_id"/)).not.toBeInTheDocument();
  });

  it("toggles Themes to JSON view and back", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    const themesToggle = screen.getByRole("button", { name: /themes.*json/i });
    fireEvent.click(themesToggle);
    expect(screen.getByText(/"theme_id"/)).toBeInTheDocument();
    expect(screen.getByText(/"Platform Reliability"/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /themes.*narrative/i }));
    expect(screen.queryByText(/"theme_id"/)).not.toBeInTheDocument();
    expect(screen.getAllByText("Platform Reliability").length).toBeGreaterThanOrEqual(1);
  });

  it("toggles Bullets to JSON view and back", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    const bulletsToggle = screen.getByRole("button", { name: /bullets.*json/i });
    fireEvent.click(bulletsToggle);
    expect(screen.getByText(/"bullets_by_theme"/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: /bullets.*narrative/i }));
    expect(screen.queryByText(/"bullets_by_theme"/)).not.toBeInTheDocument();
  });

  it("shows copy button in JSON view for Themes", () => {
    render(<NarrativeView themes={mockThemes} bullets={mockBullets} />);
    fireEvent.click(screen.getByRole("button", { name: /themes.*json/i }));
    const copyButtons = screen.getAllByRole("button", { name: /copy/i });
    expect(copyButtons.length).toBeGreaterThanOrEqual(1);
  });
});
