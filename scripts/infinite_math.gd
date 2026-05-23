class_name InfiniteMath


'''
# Tests
var a = infinite_math.float2array(12.34)
var b = infinite_math.float2array(0.56)

print("=== CUSTOM REPRESENTATION ===")
print(infinite_math.float_repr_add(a, b))
print(infinite_math.float_repr_sub(a, b))
print(infinite_math.float_repr_mul(a, b))
print(infinite_math.float_repr_div(a, b, 22))

print("")
print("=== NORMAL FLOAT RESULTS ===")
print(12.34 + 0.56)
print(12.34 - 0.56)
print(12.34 * 0.56)
print(12.34 / 0.56)
'''

func float2array(x: float) -> Array:
	var str_x: String = str(x)
	var chars = str_x.split()
	var dot_position: int
	var is_negative := false
	
	# Deal with negative numbers.
	if chars[0] == "-":
		is_negative = true
		dot_position = str_x.find(".") - 1
	# Deal with positive numbers.
	else:
		dot_position = str_x.find(".")
		
	var vals = [dot_position]
		
	for i in chars:
		if i != "-" and i != ".":
			vals.append(int(i))
	
	if is_negative:
		for i in range(1, vals.size()):
			if vals[i] != 0:
				vals[i] = -vals[i]
				break
	
	return vals
	
func _decode_repr(v: Array) -> Dictionary:
	var sign := 1
	var decimal_pos := int(v[0])
	var digits: Array[int] = []

	for i in range(1, v.size()):
		var d := int(v[i])
		if d < 0:
			sign = -1
			d = -d
		digits.append(d)

	if digits.is_empty():
		digits = [0]

	return {"sign": sign, "decimal_pos": decimal_pos, "digits": digits}

func _trim_leading_zeros(digits: Array[int]) -> Array[int]:
	if digits.is_empty():
		return [0]

	var i := 0
	while i < digits.size() - 1 and digits[i] == 0:
		i += 1

	var out: Array[int] = []
	for j in range(i, digits.size()):
		out.append(int(digits[j]))

	if out.is_empty():
		return [0]

	return out

func _align_digits(digits: Array[int], decimal_pos: int, common_int: int, common_frac: int) -> Array[int]:
	var out: Array[int] = digits.duplicate()

	var left_pad := common_int - decimal_pos
	for _i in range(left_pad):
		out.insert(0, 0)

	var current_frac := out.size() - common_int
	var right_pad := common_frac - current_frac
	for _j in range(right_pad):
		out.append(0)

	return out

func _bigint_cmp(a: Array[int], b: Array[int]) -> int:
	var aa := _trim_leading_zeros(a)
	var bb := _trim_leading_zeros(b)

	if aa.size() != bb.size():
		return 1 if aa.size() > bb.size() else -1

	for i in range(aa.size()):
		if aa[i] != bb[i]:
			return 1 if aa[i] > bb[i] else -1

	return 0

func _bigint_add(a: Array[int], b: Array[int]) -> Array[int]:
	var i := a.size() - 1
	var j := b.size() - 1
	var carry := 0
	var res_rev: Array[int] = []

	while i >= 0 or j >= 0 or carry > 0:
		var da := a[i] if i >= 0 else 0
		var db := b[j] if j >= 0 else 0
		var s := da + db + carry
		res_rev.append(s % 10)
		carry = int(s / 10)
		i -= 1
		j -= 1

	var res: Array[int] = []
	for k in range(res_rev.size() - 1, -1, -1):
		res.append(res_rev[k])

	return _trim_leading_zeros(res)

func _bigint_sub(a: Array[int], b: Array[int]) -> Array[int]:
	# Assume a >= b.
	var i := a.size() - 1
	var j := b.size() - 1
	var borrow := 0
	var res_rev: Array[int] = []

	while i >= 0:
		var da := a[i]
		var db := b[j] if j >= 0 else 0
		var d := da - borrow - db

		if d < 0:
			d += 10
			borrow = 1
		else:
			borrow = 0

		res_rev.append(d)
		i -= 1
		j -= 1

	var res: Array[int] = []
	for k in range(res_rev.size() - 1, -1, -1):
		res.append(res_rev[k])

	return _trim_leading_zeros(res)

func _bigint_mul_small(a: Array[int], m: int) -> Array[int]:
	if m == 0:
		return [0]

	var i := a.size() - 1
	var carry := 0
	var res_rev: Array[int] = []

	while i >= 0:
		var p := a[i] * m + carry
		res_rev.append(p % 10)
		carry = int(p / 10)
		i -= 1

	while carry > 0:
		res_rev.append(carry % 10)
		carry = int(carry / 10)

	var res: Array[int] = []
	for k in range(res_rev.size() - 1, -1, -1):
		res.append(res_rev[k])

	return _trim_leading_zeros(res)

func _bigint_mul(a: Array[int], b: Array[int]) -> Array[int]:
	a = _trim_leading_zeros(a)
	b = _trim_leading_zeros(b)

	if a.size() == 1 and a[0] == 0:
		return [0]
	if b.size() == 1 and b[0] == 0:
		return [0]

	var res: Array[int] = []
	for _i in range(a.size() + b.size()):
		res.append(0)

	var i := a.size() - 1
	while i >= 0:
		var j := b.size() - 1
		while j >= 0:
			var idx := i + j + 1
			var s := a[i] * b[j] + res[idx]
			res[idx] = s % 10
			res[idx - 1] += int(s / 10)
			j -= 1
		i -= 1

	# Propagate any carries leftwards.
	var k := res.size() - 1
	while k > 0:
		if res[k] >= 10:
			res[k - 1] += int(res[k] / 10)
			res[k] = res[k] % 10
		k -= 1

	return _trim_leading_zeros(res)

func _bigint_divmod(dividend: Array[int], divisor: Array[int]) -> Dictionary:
	dividend = _trim_leading_zeros(dividend)
	divisor = _trim_leading_zeros(divisor)

	if divisor.size() == 1 and divisor[0] == 0:
		push_error("Division by zero.")
		return {"quotient": [0], "remainder": [0]}

	if _bigint_cmp(dividend, divisor) < 0:
		return {"quotient": [0], "remainder": dividend}

	var quotient: Array[int] = []
	var remainder: Array[int] = [0]

	for digit in dividend:
		if remainder.size() == 1 and remainder[0] == 0:
			remainder[0] = int(digit)
		else:
			remainder.append(int(digit))

		remainder = _trim_leading_zeros(remainder)

		var lo := 0
		var hi := 9
		var qdigit := 0

		while lo <= hi:
			var mid := int((lo + hi) / 2)
			var prod := _bigint_mul_small(divisor, mid)
			var cmp := _bigint_cmp(prod, remainder)

			if cmp <= 0:
				qdigit = mid
				lo = mid + 1
			else:
				hi = mid - 1

		quotient.append(qdigit)

		if qdigit > 0:
			var sub := _bigint_mul_small(divisor, qdigit)
			remainder = _bigint_sub(remainder, sub)

	quotient = _trim_leading_zeros(quotient)
	remainder = _trim_leading_zeros(remainder)

	return {"quotient": quotient, "remainder": remainder}

func _integer_digits_to_repr(digits: Array[int], frac_count: int, sign: int) -> Array:
	var out := _trim_leading_zeros(digits)
	var decimal_pos := 1

	if out.size() <= frac_count:
		var padded: Array[int] = []
		for _i in range(frac_count + 1 - out.size()):
			padded.append(0)
		for d in out:
			padded.append(d)
		out = padded
		decimal_pos = 1
	else:
		decimal_pos = out.size() - frac_count

	# Remove zeros from the integer part if possible.
	while out.size() > 1 and decimal_pos > 1 and out[0] == 0:
		out.remove_at(0)
		decimal_pos -= 1

	# Remove trailing zeros after the decimal point.
	while out.size() > decimal_pos and out[out.size() - 1] == 0:
		out.remove_at(out.size() - 1)

	# Zero.
	var all_zero := true
	for d in out:
		if d != 0:
			all_zero = false
			break

	if all_zero:
		return [1, 0]

	if sign < 0:
		for i in range(out.size()):
			if out[i] != 0:
				out[i] = -out[i]
				break

	return [decimal_pos] + out

func _negate_repr(v: Array) -> Array:
	var out := v.duplicate()
	for i in range(1, out.size()):
		var d := int(out[i])
		if d != 0:
			out[i] = -d
			break
			
	return out

func float_repr_add(a: Array, b: Array) -> Array:
	var A := _decode_repr(a)
	var B := _decode_repr(b)

	var a_int := int(A["decimal_pos"])
	var b_int := int(B["decimal_pos"])
	var a_frac := int(A["digits"].size()) - a_int
	var b_frac := int(B["digits"].size()) - b_int

	var common_int := maxi(a_int, b_int)
	var common_frac := maxi(a_frac, b_frac)

	var a_al := _align_digits(A["digits"], a_int, common_int, common_frac)
	var b_al := _align_digits(B["digits"], b_int, common_int, common_frac)

	var result_digits: Array[int]
	var result_sign := 1

	if int(A["sign"]) == int(B["sign"]):
		result_sign = int(A["sign"])
		result_digits = _bigint_add(a_al, b_al)
	else:
		var cmp := _bigint_cmp(a_al, b_al)

		if cmp == 0:
			return [1, 0]

		if cmp > 0:
			result_sign = int(A["sign"])
			result_digits = _bigint_sub(a_al, b_al)
		else:
			result_sign = int(B["sign"])
			result_digits = _bigint_sub(b_al, a_al)

	return _integer_digits_to_repr(result_digits, common_frac, result_sign)

func float_repr_sub(a: Array, b: Array) -> Array:
	return float_repr_add(a, _negate_repr(b))

func float_repr_mul(a: Array, b: Array) -> Array:
	var A := _decode_repr(a)
	var B := _decode_repr(b)

	var sign := int(A["sign"]) * int(B["sign"])
	var a_frac := int(A["digits"].size()) - int(A["decimal_pos"])
	var b_frac := int(B["digits"].size()) - int(B["decimal_pos"])
	var total_frac := a_frac + b_frac

	var product := _bigint_mul(A["digits"], B["digits"])

	return _integer_digits_to_repr(product, total_frac, sign)

func float_repr_div(a: Array, b: Array, precision: int = 12) -> Array:
	var A := _decode_repr(a)
	var B := _decode_repr(b)

	if B["digits"].size() == 1 and int(B["digits"][0]) == 0:
		push_error("Division by zero.")
		return [1, 0]

	var sign := int(A["sign"]) * int(B["sign"])

	var a_frac := int(A["digits"].size()) - int(A["decimal_pos"])
	var b_frac := int(B["digits"].size()) - int(B["decimal_pos"])

	# A / B = (Na * 10^b_frac) / (Nb * 10^a_frac)
	# Multiply numerator by 10^precision to get truncated decimal digits.
	var dividend: Array[int] = A["digits"].duplicate()
	for _i in range(b_frac + precision):
		dividend.append(0)

	var divisor: Array[int] = B["digits"].duplicate()
	for _j in range(a_frac):
		divisor.append(0)

	var divres := _bigint_divmod(dividend, divisor)
	var quotient: Array[int] = []
	for v in divres["quotient"]:
		quotient.append(v)

	return _integer_digits_to_repr(quotient, precision, sign)

func array2float(v: Array) -> float:
	if v.size() <= 1:
		return 0.0

	var decimal_pos := int(v[0])
	var sign := 1
	var digits := ""

	for i in range(1, v.size()):
		var d := int(v[i])

		if d < 0:
			sign = -1
			d = -d

		digits += str(d)

	# Pad if decimal position exceeds digits length.
	while digits.length() < decimal_pos:
		digits += "0"

	var result: String

	if decimal_pos <= 0:
		result = "0."
		
		for _i in range(-decimal_pos):
			result += "0"
			
		result += digits
	else:
		result = digits.substr(0, decimal_pos)

		if decimal_pos < digits.length():
			result += "." + digits.substr(decimal_pos)

	if sign < 0:
		result = "-" + result

	return float(result)
	
func array2string(v: Array) -> String:
	if v.size() <= 1:
		return "0"

	var decimal_pos := int(v[0])
	var sign := 1
	var digits := ""

	for i in range(1, v.size()):
		var d := int(v[i])
		if d < 0:
			sign = -1
			d = -d
		digits += str(d)

	# Garante que exista pelo menos a parte inteira pedida.
	while digits.length() < decimal_pos:
		digits += "0"

	var result := ""

	if decimal_pos <= 0:
		result = "0."
		for _i in range(-decimal_pos):
			result += "0"
		result += digits
	else:
		result = digits.substr(0, decimal_pos)

		if decimal_pos < digits.length():
			result += "." + digits.substr(decimal_pos)

	# Remove o sinal de zero.
	if sign < 0 and result != "0":
		result = "-" + result

	return result
