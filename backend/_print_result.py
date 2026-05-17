import json
import sys

d = json.load(open("temp_result.json", encoding="utf-8"))
print("Title:", d["title"])
print(f"Steps: {len(d['steps'])}")
for i, s in enumerate(d["steps"]):
    print(f"  Step {i+1}:")
    print(f"    instruction: {s['instruction']}")
    print(f"    rect: {s['rect']}")
    print(f"    bubble_dir: {s['bubble_dir']}")
