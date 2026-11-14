// SPDX-FileCopyrightText: 2026 comfydv
//
// SPDX-License-Identifier: MPL-2.0

// Written by tools/capture.sh.
#let unhealthy-after = read("captures/db-failure-timing.txt").find(regex("\d+"))

// Every slide heading (`==`) needs a cue unless tagged <no-cue>.
// The title and closing slides have no `==` heading; `.before(<deck-end>)` skips the speech.
#let check-cues() = context {
  let cued = query(<cue>).map(m => m.value)
  for h in query(heading.where(level: 2).before(<deck-end>)) {
    let l = h.at("label", default: none)
    if l != <no-cue> and l not in cued {
      panic("slide without a cue: " + repr(h.body))
    }
  }
}

// Page setup and helper macros for speech.typ. Usage: #show: speech
#let speech(body) = {
  set page(paper: "a4", numbering: "1")
  set text(lang: "ru", size: 12pt)
  set par(justify: true)
  show heading.where(level: 2): set block(above: 1.6em, below: 0.8em)
  show heading.where(level: 3): set block(above: 1.3em, below: 0.7em)
  show link: underline
  body
  check-cues()
}

#let demo(body) = block(
  fill: luma(238),
  inset: 9pt,
  radius: 3pt,
  width: 100%,
)[*На слайде.* #body]

#let cue-mark(n) = box(
  fill: rgb("#eb811b"),
  radius: 2pt,
  inset: (x: 3pt, y: 1pt),
  baseline: 15%,
  text(fill: white, size: 9pt, weight: "bold")[#sym.triangle.filled.r #n],
)

// Slide labels live in slides.typ and resolve only in the bundle build (talk.typ).
#let cue(target) = [#metadata(target) <cue>#context cue-mark(locate(target).page())]

#let todo(body) = highlight(fill: yellow)[#body]
#let who(speaker, minutes) = block(below: 1em, text(fill: luma(100))[
  #speaker #sym.dot.c около #minutes мин
])
