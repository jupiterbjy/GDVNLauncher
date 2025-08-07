class_name ArrayUtils


# --- Value Search ---

## Finds largest in array. Assumes array is always populated and not sorted
static func arr_max(arr: Array[Variant]) -> Variant:
	var largest: Variant = arr[0]
	for idx: int in range(1, len(arr)):
		if arr[idx] > largest:
			largest = arr[idx]

	return largest


## Finds largest in array. Assumes array is always populated and not sorted
static func arr_max_f32(arr: PackedFloat32Array) -> float:
	var largest: float = arr[0]
	for idx: int in range(1, len(arr)):
		if arr[idx] > largest:
			largest = arr[idx]

	return largest


## Finds smallest in array. Assumes array is always populated and not sorted
static func arr_min(arr: Array[Variant]) -> Variant:
	var smallest: Variant = arr[0]
	for idx: int in range(1, len(arr)):
		if arr[idx] < smallest:
			smallest = arr[idx]

	return smallest


## Finds smallest in array. Assumes array is always populated and not sorted
static func arr_min_f32(arr: PackedFloat32Array) -> float:
	var smallest: float = arr[0]
	for idx: int in range(1, len(arr)):
		if arr[idx] < smallest:
			smallest = arr[idx]

	return smallest


## Finds largest absolute value in array. Assumes array is always populated and not sorted
static func arr_abs_max(arr: Array[Variant]) -> Variant:
	var largest: Variant = arr[0]
	for idx: int in range(1, len(arr)):
		var val: Variant = abs(arr[idx])
		if val > largest:
			largest = val

	return largest


## Finds largest absolute value in array. Assumes array is always populated and not sorted
static func arr_abs_max_f32(arr: PackedFloat32Array) -> float:
	var largest: float = arr[0]
	for idx: int in range(1, len(arr)):
		var val: float = abs(arr[idx])
		if val > largest:
			largest = val

	return largest


# --- Element-wise Arithmetic ---

## Perform div on each array element, inplace.
## Also Returns given array in case of PackedArray which seems to converted to Array.
## But prefer calling matching method for packed arrays.
static func arr_div(arr: Array[Variant], divisor: Variant) -> Array[Variant]:
	for idx: int in range(len(arr)):
		arr[idx] /= divisor

	return arr


## Perform div on each array element, inplace.
static func arr_div_f32(arr: PackedFloat32Array, divisor: float) -> PackedFloat32Array:
	for idx: int in range(len(arr)):
		arr[idx] /= divisor

	return arr


## Perform mult on each array element, inplace.
## Also Returns given array in case of PackedArray which seems converted to Array.
## But prefer calling matching method for packed arrays.
static func arr_mul(arr: Array[Variant], multiplier: Variant) -> Array[Variant]:
	for idx: int in range(len(arr)):
		arr[idx] *= multiplier

	return arr


## Perform mult on each array element, inplace.
static func arr_mul_f32(arr: PackedFloat32Array, multiplier: float) -> PackedFloat32Array:
	for idx: int in range(len(arr)):
		arr[idx] *= multiplier

	return arr


## Perform add on each array element, inplace.
## Also Returns given array in case of PackedArray which seems converted to Array.
## But prefer calling matching method for packed arrays.
static func arr_add(arr: Array[Variant], addition: Variant) -> Array[Variant]:
	for idx: int in range(len(arr)):
		arr[idx] += addition

	return arr


## Perform add on each array element, inplace.
static func arr_add_f32(arr: PackedFloat32Array, addition: float) -> PackedFloat32Array:
	for idx: int in range(len(arr)):
		arr[idx] += addition

	return arr


## Perform sub on each array element, inplace.
## Also Returns given array in case of PackedArray which is treated call-by-value unlike python
## But prefer calling matching method for packed arrays.
static func arr_sub(arr: Array[Variant], subtraction: Variant) -> Array[Variant]:
	for idx: int in range(len(arr)):
		arr[idx] -= subtraction

	return arr


## Perform sub on each array element, inplace.
static func arr_sub_f32(arr: PackedFloat32Array, subtraction: float) -> PackedFloat32Array:
	for idx: int in range(len(arr)):
		arr[idx] -= subtraction

	return arr


# --- Array-Array Operations ---

## [*itertools.chain(*zip(*arrs))]. Assumes all array lengths are equal.
static func chained_zip(arrs: Array[Array]) -> Array[Variant]:
	var result: Array[Variant]
	result.resize(len(arrs) * len(arrs[0]))
	var count: int = 0

	for item_idx: int in range(len(arrs[0])):
		for arr_idx: int in range(len(arrs)):
			result[count] = arrs[arr_idx][item_idx]
			count += 1

	return result


## [*itertools.chain(*zip(*arrs))]. Assumes all array lengths are equal.
static func chained_zip_f32(arrs: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var result: PackedFloat32Array
	result.resize(len(arrs) * len(arrs[0]))
	var count: int = 0

	for item_idx: int in range(len(arrs[0])):
		for arr_idx: int in range(len(arrs)):
			result[count] = arrs[arr_idx][item_idx]
			count += 1

	return result
