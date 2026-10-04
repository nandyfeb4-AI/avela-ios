// Local SVG APPROXIMATIONS of SF Symbols. Keyed by the intended SF Symbol name.
// The native app must use Image(systemName:) with these names; these drawings
// exist only so the prototype has no external dependencies. Verify every name
// in the SF Symbols app (see design/exploration/ICON_SYSTEM.md).

window.AvelaPrototype = window.AvelaPrototype || {};

window.AvelaPrototype.ICONS = {
  "checkmark": '<path d="M5 12.6l4.6 4.6L19.4 7" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
  "plus": '<path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/>',
  "chevron.left": '<path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
  "chevron.right": '<path d="M9 5l7 7-7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
  "chevron.down": '<path d="M5 9l7 7 7-7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
  "arrow.clockwise": '<path d="M19 12.5a7 7 0 1 1-2.1-5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/><path d="M18.8 3.6v4.6h-4.6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
  "drop.fill": '<path d="M12 2.8C9 7.4 5.8 10.6 5.8 14.6a6.2 6.2 0 0 0 12.4 0c0-4-3.2-7.2-6.2-11.8z" fill="currentColor"/>',
  "book.fill": '<path d="M2.5 5.6c3.2-1.4 6.4-1.2 8.7.7v13.4c-2.3-1.6-5.5-1.8-8.7-.6z M21.5 5.6c-3.2-1.4-6.4-1.2-8.7.7v13.4c2.3-1.6 5.5-1.8 8.7-.6z" fill="currentColor"/>',
  "pencil.line": '<path d="M4 16.8L15.4 5.4l3.2 3.2L7.2 20H4z" fill="currentColor"/><path d="M12 21h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  "figure.walk": '<circle cx="13.6" cy="3.9" r="2.1" fill="currentColor"/><path d="M12.6 7.6l-2 5.6 3.2 3.2 1 4.8M10.6 13.2l-2.4 7M12.4 8.2l-3.6 2.6-.6 3M12.8 8.4l1.6 3.4 3 1.2" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
  "iphone.slash": '<rect x="7" y="2.8" width="10" height="18.4" rx="2.6" fill="none" stroke="currentColor" stroke-width="2"/><path d="M4 4l16 16" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
  "pills.fill": '<rect x="3.5" y="8.5" width="17" height="7" rx="3.5" transform="rotate(-35 12 12)" fill="currentColor"/>',
  "bubble.left.fill": '<path d="M4 6.5A3 3 0 0 1 7 3.5h10a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3h-7l-4.5 3.5V16.3A3 3 0 0 1 4 13.5z" fill="currentColor"/>',
  "phone.fill": '<path d="M6.6 3.5l3 .6 1.2 3.9-2 1.6a12 12 0 0 0 5.6 5.6l1.6-2 3.9 1.2.6 3c.1.8-.5 1.6-1.4 1.6C10.3 19 5 13.7 5 5c0-.9.8-1.6 1.6-1.5z" fill="currentColor"/>',
  "sparkles": '<path d="M10 3l1.6 4.8L16.4 9.4l-4.8 1.6L10 15.8 8.4 11 3.6 9.4l4.8-1.6z" fill="currentColor"/><path d="M18 13.5l.9 2.4 2.4.9-2.4.9-.9 2.4-.9-2.4-2.4-.9 2.4-.9z" fill="currentColor"/>',
  "nosign": '<circle cx="12" cy="12" r="8.4" fill="none" stroke="currentColor" stroke-width="2.2"/><path d="M6.2 6.2l11.6 11.6" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
  "figure.cooldown": '<circle cx="12" cy="4" r="2.1" fill="currentColor"/><path d="M12 7.4v6.2M12 13.6l-4.4 6.4M12 13.6l4.4 6.4M5.6 9.4l6.4 1.4 6.4-1.4" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
  "hourglass": '<path d="M6 3h12M6 21h12M7.5 3c0 5 9 5 9 9s-9 4-9 9M16.5 3c0 5-9 5-9 9s9 4 9 9" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  "calendar": '<rect x="3.5" y="5" width="17" height="15.5" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M3.5 9.5h17M8 3v4M16 3v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  "archivebox": '<rect x="3" y="4" width="18" height="5" rx="1.4" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M4.6 9v9.5a1.8 1.8 0 0 0 1.8 1.8h11.2a1.8 1.8 0 0 0 1.8-1.8V9M9.5 13h5" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  "forward.end": '<path d="M5 6l9 6-9 6z" fill="currentColor"/><path d="M17.5 6v12" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/>',
  "sun.max": '<circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M5.3 18.7l1.5-1.5M17.2 6.8l1.5-1.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  "sun.max.fill": '<circle cx="12" cy="12" r="4.8" fill="currentColor"/><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M5.3 18.7l1.5-1.5M17.2 6.8l1.5-1.5" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>',
  "chart.bar.xaxis": '<path d="M3.5 20.5h17" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><rect x="5" y="11" width="3.4" height="7" rx="1" fill="currentColor"/><rect x="10.3" y="5" width="3.4" height="13" rx="1" fill="currentColor"/><rect x="15.6" y="8.5" width="3.4" height="9.5" rx="1" fill="currentColor"/>',
  "gearshape": '<circle cx="12" cy="12" r="6.6" fill="none" stroke="currentColor" stroke-width="3.2" stroke-dasharray="2.6 2.6"/><circle cx="12" cy="12" r="5.6" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="12" r="2.2" fill="none" stroke="currentColor" stroke-width="1.8"/>',
};

// Returns an inline SVG string. `data-symbol` carries the intended SF Symbol
// name so the reviewer "Show SF Symbol names" toggle can label every icon.
window.AvelaPrototype.icon = function icon(name, size, extraClass) {
  const body = window.AvelaPrototype.ICONS[name];
  if (!body) throw new Error("Unknown icon approximation: " + name);
  return '<span class="sym ' + (extraClass || "") + '" data-symbol="' + name + '">' +
    '<svg width="' + size + '" height="' + size + '" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
    '<title>SF Symbol (approximation): ' + name + '</title>' + body + '</svg></span>';
};
