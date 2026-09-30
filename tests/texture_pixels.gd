@tool
extends RefCounted

## Test helper, not a suite: a texture's pixels as an Image a test can read.
##
## Large art is imported VRAM-compressed (tests/test_texture_memory.gd), and
## `Texture2D.get_image()` hands such a texture back still compressed:
## `get_pixel` on it logs an error per call and returns nothing useful, and a
## per-pixel loop over a 1280 px face hangs the editor on the error spam.
## Every suite that reads pixels goes through here instead.


## `tex`'s pixels, unpacked if the import compressed them; null for a null
## texture or an unreadable one.
static func of(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img := tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	return img
