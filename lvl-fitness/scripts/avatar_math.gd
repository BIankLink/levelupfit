extends RefCounted
## Turns saved data (weigh-ins, stats, profile) into the numbers that shape the avatar.
##   fat    0.0 = lean ... 1.0 = heavy   (from body fat %)
##   muscle 0.0 = slim ... 1.0 = muscular (from Strength, a little Vitality, and muscle % if given)

# Body fat % that maps to the lean end and the heavy end of the avatar, per silhouette.
const BODY_FAT_RANGE := {
	"male": [10.0, 40.0],
	"female": [18.0, 48.0],
	"neutral": [14.0, 44.0],
}
const SMOOTH_COUNT := 3  # the avatar follows the average of the last 3 weigh-ins


static func fat_axis(sex: String, body_fat_pct: float) -> float:
	var bounds: Array = BODY_FAT_RANGE.get(sex, BODY_FAT_RANGE["neutral"])
	var low := float(bounds[0])
	var high := float(bounds[1])
	return clampf((body_fat_pct - low) / (high - low), 0.0, 1.0)


## Average of a field over the last few weigh-ins that have it, or -1.0 if none do.
static func recent_average(key: String) -> float:
	var entries: Array = SaveData.data["weigh_ins"]
	var total := 0.0
	var count := 0
	for i in range(entries.size() - 1, -1, -1):
		if entries[i].has(key):
			total += float(entries[i][key])
			count += 1
			if count >= SMOOTH_COUNT:
				break
	if count == 0:
		return -1.0
	return total / count


static func latest_weigh_in() -> Dictionary:
	var entries: Array = SaveData.data["weigh_ins"]
	if entries.is_empty():
		return {}
	return entries[entries.size() - 1]


static func muscle_axis() -> float:
	var strength := StatsManager.get_value("strength")
	var vitality := StatsManager.get_value("vitality")
	# Diminishing returns: early points show quickly, the top end takes a long time.
	var m := 0.85 * (1.0 - exp(-strength / 2500.0)) + 0.15 * (1.0 - exp(-vitality / 6000.0))
	var muscle_pct := recent_average("muscle_pct")
	if muscle_pct > 0.0:
		var scan := clampf((muscle_pct - 30.0) / 25.0, 0.0, 1.0)
		m = 0.75 * m + 0.25 * scan
	return clampf(m, 0.0, 1.0)


static func compute() -> Dictionary:
	var sex: String = SaveData.data["profile"]["sex"]
	var weight := recent_average("weight_kg")
	var body_fat := recent_average("body_fat_pct")
	var has_data := weight > 0.0 and body_fat > 0.0

	var fat := 0.5
	if has_data:
		fat = fat_axis(sex, body_fat)
	var muscle := muscle_axis()

	return {
		"sex": sex,
		"has_data": has_data,
		"fat": fat,
		"muscle": muscle,
	}
