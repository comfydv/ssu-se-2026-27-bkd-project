// SPDX-FileCopyrightText: 2026 comfydv
//
// SPDX-License-Identifier: MPL-2.0

#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// Written by tools/capture.sh.
#let unhealthy-after = read("captures/db-failure-timing.txt").find(regex("\d+"))

#let docker-logo(h) = image("img/docker-logo.svg", height: h)
#let podman-logo(h) = image("img/podman-logo.svg", height: h)
#let icon(name, h) = box(baseline: 20%, image("img/" + name, height: h))
#let docker-icon(h) = icon("docker-icon.svg", h)
#let podman-icon(h) = icon("podman-icon.svg", h)
#let accent = rgb("#eb811b")
#let box-fill = luma(238)
#let warm-fill = accent.lighten(80%)
#let e(..args) = edge(label-sep: 0.55em, ..args)
#let muted(body) = text(fill: luma(110), size: 0.8em, body)
#let small(body) = text(size: 0.8em, body)

// Theme and global styles. Usage: #show: deck.with(title: [...], subtitle: [...], author: ...)
#let deck(title: none, subtitle: none, author: none, body) = {
  show: metropolis-theme.with(
    aspect-ratio: "16-9",
    footer: self => self.info.title,
    footer-right: context [#here().page() / #locate(<deck-end>).page()],
    config-common(new-section-slide-fn: none, horizontal-line-to-pagebreak: false),
    config-info(title: title, subtitle: subtitle, author: author),
  )
  set text(lang: "ru", size: 22pt)
  show raw.where(block: true): set text(size: 15pt)
  show raw.where(block: true): it => block(
    fill: luma(240),
    inset: 10pt,
    radius: 3pt,
    width: 100%,
    it,
  )
  show link: underline
  body
}

#let todo(body) = highlight(fill: yellow)[#body]
#let key(body) = block(
  stroke: (left: 3pt + accent),
  inset: (left: 10pt, y: 6pt),
  body,
)
#let layer(body, fill: box-fill, stroke: 1pt + luma(120)) = block(
  width: 100%,
  inset: 9pt,
  radius: 4pt,
  fill: fill,
  stroke: stroke,
  align(center, small(body)),
)

// Terminal window filled with output captured on Podman (talk/captures/*.txt).
#let terminal(path, title: "podman", size: 13pt) = {
  let lines = read(path).trim(at: end).split("\n")
  block(width: 100%, radius: 7pt, clip: true, fill: rgb("#1f2430"), {
    block(width: 100%, fill: rgb("#2d3345"), inset: (x: 10pt, y: 6pt), spacing: 0pt, stack(
      dir: ltr,
      spacing: 5pt,
      circle(radius: 4pt, fill: rgb("#ff5f57")),
      circle(radius: 4pt, fill: rgb("#febc2e")),
      circle(radius: 4pt, fill: rgb("#28c840")),
      h(8pt),
      text(size: 10pt, fill: luma(175), title),
    ))
    block(width: 100%, inset: (x: 12pt, y: 9pt), spacing: 0pt, {
      set text(size: size)
      set par(leading: 0.42em, justify: false)
      for line in lines {
        let colour = if line.starts-with("$ ") { rgb("#8bd5a0") } else { rgb("#dde3ec") }
        text(fill: colour, raw(line))
        linebreak()
      }
    })
  })
}

#let LaTeX = box({
  [L]
  h(-0.30em)
  text(size: 0.7em, baseline: -0.22em)[A]
  h(-0.13em)
  [T]
  h(-0.15em)
  text(baseline: 0.16em)[E]
  h(-0.125em)
  [X]
})

// cat.svg has a 4pt margin for the strokes; the negative pad keeps the old layout size.
#let cat = pad(-4pt, image("img/cat.svg"))

// Label pill under a sticker: width follows the text
#let pill(body) = context {
  let t = text(size: 14pt, weight: "bold", fill: black, body)
  let pad = (x: 0.4cm, y: 0.18cm)
  box(width: measure(t).width + 2 * pad.x, fill: white, radius: 0.25cm, inset: pad, align(center, t))
}

// Round sticker: white rim, shadow, tilt
#let sticker(body, size: 3.2cm, angle: 0deg, label: none) = rotate(angle, reflow: true, box({
  let border = 0.16cm
  let d = size + 2 * border
  place(dx: 0.12cm, dy: 0.18cm, circle(radius: d / 2, fill: black.transparentize(55%), stroke: none))
  box(fill: white, radius: 50%, inset: border,
    box(width: size, height: size, radius: 50%, clip: true, body))
  if label != none {
    place(bottom + center, dy: 0.3cm, pill(label))
  }
}))
#let photo(path) = image(path, width: 100%, height: 100%, fit: "cover")
#let logo(path, k: 70%) = align(center + horizon, image(path, width: k))
