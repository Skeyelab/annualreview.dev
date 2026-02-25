/**
 * @vitest-environment jsdom
 */
import React from "react";
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import Landing from "../src/Landing.jsx";

describe("Landing", () => {
  it("renders brand name and primary CTA", () => {
    render(<Landing />);
    expect(screen.getByRole("link", { name: /generate a review/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /generate a review/i })).toHaveAttribute("href", "/generate");
    const header = screen.getByRole("banner");
    expect(header).toHaveTextContent("AnnualReview.dev");
  });

  it("renders How it works section with four steps", () => {
    render(<Landing />);
    expect(screen.getByRole("heading", { name: /how it works/i })).toBeInTheDocument();
    const list = screen.getByRole("list", { name: "" });
    expect(list).toHaveTextContent("Sign in with GitHub");
    expect(list).toHaveTextContent("Choose date range");
    expect(list).toHaveTextContent("Get themes, bullets");
    expect(list).toHaveTextContent("Export to Markdown");
  });

  it("renders hero title and Connect GitHub link", () => {
    render(<Landing />);
    expect(screen.getByRole("heading", { name: /turn your contributions/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /connect github/i })).toHaveAttribute("href", "/api/auth/github");
  });
});
