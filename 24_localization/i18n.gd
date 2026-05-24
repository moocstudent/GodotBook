extends RefCounted
class_name I18n

# ╔══════════════════════════════════════════════════════════════╗
# ║  最小 i18n 加载器                                              ║
# ║                                                              ║
# ║  正规做法:把 strings.csv 拖进项目,Godot 自动 import 成        ║
# ║  .translation 文件,在 Project Settings → Localization →      ║
# ║  Translations 列表里加进去 → 自动通过 TranslationServer 生效。  ║
# ║                                                              ║
# ║  本 demo 演示**程序化加载**:在运行时 parse CSV,构造           ║
# ║  Translation 资源 -> TranslationServer.add_translation()。   ║
# ║  好处:同 CSV 文件随项目走,无需手动配置导入设置。              ║
# ╚══════════════════════════════════════════════════════════════╝

static func load_csv(path: String) -> PackedStringArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开 " + path)
		return PackedStringArray()

	var lines: PackedStringArray = []
	while not file.eof_reached():
		var line := file.get_line()
		if line != "" or not file.eof_reached():
			lines.append(line)
	# 末尾空行去掉
	while lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	return lines

# 简易 CSV 解析:支持 "..." 包裹的字段(里面可以有逗号)
static func parse_csv_line(line: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	var in_quote := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if in_quote:
			if ch == "\"":
				# 连续两个 "" = 一个 " 字面值
				if i + 1 < line.length() and line[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					in_quote = false
			else:
				cur += ch
		else:
			if ch == "\"":
				in_quote = true
			elif ch == ",":
				out.append(cur)
				cur = ""
			else:
				cur += ch
		i += 1
	out.append(cur)
	return out

static func install(csv_path: String) -> PackedStringArray:
	# 返回所有 locale 列表,方便上层做语言选择 UI
	var lines := load_csv(csv_path)
	if lines.size() < 2:
		push_error("CSV 至少两行(header + 数据)")
		return PackedStringArray()

	var header := parse_csv_line(lines[0])
	# 第一列必须是 "keys" 或 "key"
	var locales: PackedStringArray = []
	for i in range(1, header.size()):
		locales.append(header[i].strip_edges())

	# 每个 locale 一份 Translation
	var translations := {}
	for loc in locales:
		var t := Translation.new()
		t.locale = loc
		translations[loc] = t

	for li in range(1, lines.size()):
		var parts := parse_csv_line(lines[li])
		if parts.size() < 2:
			continue
		var key := parts[0].strip_edges()
		if key.is_empty():
			continue
		for ci in range(locales.size()):
			var value := parts[ci + 1] if ci + 1 < parts.size() else ""
			(translations[locales[ci]] as Translation).add_message(key, value)

	for t in translations.values():
		TranslationServer.add_translation(t)

	return locales
