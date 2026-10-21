import assert from "node:assert/strict";
import test from "node:test";
import { canonicalSectionRef, normalizeEvidenceRefs } from "../src/analysis/evidenceRefs.js";

test("known section spellings map to the canonical sections.<name>", () => {
  for (const variant of ["sections.recentForm", "recentForm", "Recent Form", "recent_form", "sections.recentForm.last5", "sections/recentForm"]) {
    assert.equal(canonicalSectionRef(variant), "sections.recentForm", variant);
  }
  assert.equal(canonicalSectionRef("head to head"), "sections.headToHead");
  assert.equal(canonicalSectionRef("sections.squadAvailability"), "sections.squadAvailability");
});

test("unknown or non-string references are dropped, never invented", () => {
  assert.equal(canonicalSectionRef("sections.transfers"), null);
  assert.equal(canonicalSectionRef("The team has been strong lately"), null);
  assert.equal(canonicalSectionRef(42), null);
});

test("normalization dedupes references and leaves other fields untouched", () => {
  const raw = {
    status: "ready",
    rationale: [
      { code: "FORM", text: "x", evidenceRefs: ["recentForm", "sections.recentForm", "Standings"] },
      { code: "NONE", text: "y", evidenceRefs: ["nonsense"] },
    ],
  };
  const result = normalizeEvidenceRefs(raw) as typeof raw;
  assert.deepEqual(result.rationale[0]?.evidenceRefs, ["sections.recentForm", "sections.standings"]);
  assert.deepEqual(result.rationale[1]?.evidenceRefs, []);
  assert.equal(result.status, "ready");
  assert.equal(normalizeEvidenceRefs("not an object"), "not an object");
});
