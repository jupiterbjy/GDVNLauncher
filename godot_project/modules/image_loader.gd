class_name ImageLoader
## Loads unknown image types, because having another column in DB is pain.
##
## Refer: https://forum.godotengine.org/t/how-to-load-image-from-buffer-without-knowing-the-file-type/102195/8
## for explanation.
##
## :Author: jupiterbjy@gmail.com


# --- Attributes ---

const _PNG_HEADER: PackedByteArray = [137, 80, 78, 71, 13, 10, 26, 10]

const _JPG_HEADER: PackedByteArray = [255, 216, 255]

const _WEBP_HEADER: PackedByteArray = [82, 73, 70, 70]

const _BMP_HEADER: PackedByteArray = [66, 77]
# do vndb even have bmp as thumbnail or cover image...?

## Maps header to loader method in `Image`.
const _HEADER_MAPPING: Dictionary[PackedByteArray, StringName] = {
	_PNG_HEADER: &"load_png_from_buffer",
	_JPG_HEADER: &"load_jpg_from_buffer",
	_WEBP_HEADER: &"load_webp_from_buffer",
	_BMP_HEADER: &"load_bmp_from_buffer",
}


# --- Methods ---

## Tries to load image from bytes based on magic numbers. Returns null on failure.
static func bytes_to_img(bytes: PackedByteArray) -> Image:

	for header: PackedByteArray in _HEADER_MAPPING:

		# barely likely but sanity check
		if len(header) >= len(bytes):
			continue

		# match magic backward for convenience
		var match_pos: int = len(header) - 1

		while match_pos >= 0 and header[match_pos] == bytes[match_pos]:
			match_pos -= 1

		# if there's remaining match no luck
		if match_pos >= 0:
			continue

		# else found match
		var img := Image.new()
		var err: Error = img.call(_HEADER_MAPPING[header], bytes)

		return img if err == Error.OK else null

	return null


## bytes_to_image but as new Texture2D. Returns null on failure.
static func bytes_to_tex(bytes: PackedByteArray) -> ImageTexture:
	var img := bytes_to_img(bytes)
	if not img:
		return null

	return ImageTexture.create_from_image(img)
