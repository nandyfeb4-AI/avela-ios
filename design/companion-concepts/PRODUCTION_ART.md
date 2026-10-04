# Native companion artwork

Created 2026-10-04 using the built-in image-generation tool. No image service or
AI SDK runs in Avela. The original exploration board is the visual reference,
not a shipping asset. Production PNGs are in
`Avela/Resources/CompanionAssets.xcassets`, bundled in app and widget targets.
The owl remains the default; fox and otter preserve the existing choice.

## Atlas contract

Each transparent 1536 × 1024 atlas contains six 512 × 512 cells in a 3-column,
2-row grid, read left to right then top to bottom:

1. Calm: relaxed upright, friendly open eyes.
2. Focused: attentive upright, quietly intent eyes.
3. Near limit: thoughtful head tilt and one lifted wing/paw; observant.
4. Overloaded: peacefully resting with closed eyes, inviting a pause.
5. Recovering: a small step forward, hopeful open eyes.
6. Celebrating: modest joyful wing/paw lift, warm happy eyes.

`CompanionArtwork` crops the corresponding cell at runtime and caches native
256-pixel images, lazily per animal. Alpha is preserved by Apple's renderer.
There are no timer-driven idle loops. Today has a short pose crossfade and a
small celebration scale change; Reduce Motion disables both. Artwork is
decorative to VoiceOver; the card's text and state description carry its meaning.
At accessibility text sizes the card stacks vertically without compressing text.

Home Screen widgets render the exported selected animal and evaluated state.
Disabled companions, old snapshots without preference fields and stale snapshots
show no art. Lock Screen summaries remain text. Widgets never persist a
celebration from a saved completion: that pose is an app-only transient event.

## Prompt set

One built-in generation call per animal atlas, using the original board as the
reference and `transparent_background: true`. Shared direction:

> Create a production transparent PNG sprite atlas for the original animal
> companion in Avela, based only on that animal in the supplied reference board.
> Simplify intricate fur/feathers into broad polished sculptural shapes with
> subtle satin shading; premium adult wellness/productivity brand, friendly but
> not infantile or generic stock clip art. Preserve animal anatomy, facial
> identity and natural colors. No accessories, clothes, logos or resemblance to
> an existing app mascot. Exactly six poses in a uniform 3-column by 2-row grid
> in the order above. One full-body animal per cell, consistent camera,
> proportions, rendering and lighting. Landscape 1536 × 1024 canvas; equal
> 512 × 512 cells; no grid lines. Center each animal horizontally on the same
> baseline at 85% of cell height, occupying about 65–70% cell height with
> generous transparent margins, never crossing cell boundaries. Genuine alpha,
> clean edges, no backdrop/checkerboard/floor shadow/labels/text. Identifiable
> when a cell is displayed at 64 points.

Animal-specific palette directions:

- Owl: teal wing tips, ivory face/belly, warm amber edges.
- Fox: warm russet body, ivory chest and tail tip, dark paws, muted teal accent.
- Otter: warm taupe/brown body, ivory muzzle/chest, muted teal accent.

The resulting assets retain more detailed texture than the prompt requested;
this is visible in the sources. Native app-size screenshots, rather than an
enlarged atlas preview, establish how that detail reads in the actual card.
Physical-device OLED, VoiceOver and widget provisioning checks remain release
gates. No permanent Dynamic Island companion is implemented.

## Owl spacing correction

A native dark-mode capture exposed a small neighboring feather fragment at the
recovering cell boundary. A targeted built-in image edit requested the same six
poses, character identity and transparent atlas, with each animal isolated within
its own 512-pixel cell and generous clear margins. The final owl asset is
`states-v2.png`; the original is preserved at `iterations/owl-v1.png`. No
third-party runtime tooling or offline raster manipulation was introduced.
