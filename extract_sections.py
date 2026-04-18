"""
extract_sections.py
Parse all GROBID XML files and extract introduction, methods, and discussion text.
Saves to claude_results/sections.json for downstream classification.
"""
import os, json, re
from xml.etree import ElementTree as ET

XML_DIR = os.path.join(os.path.dirname(__file__), "files", "xml_files_theory")
OUT_DIR = os.path.join(os.path.dirname(__file__), "claude_results")
os.makedirs(OUT_DIR, exist_ok=True)

NS = {"tei": "http://www.tei-c.org/ns/1.0"}

def get_text(div):
    """Recursively extract all text from a div, stripping citations/refs."""
    parts = []
    for elem in div.iter():
        if elem.tag in (f"{{{NS['tei']}}}ref",):
            continue  # skip citation markers
        if elem.text:
            parts.append(elem.text.strip())
        if elem.tail:
            parts.append(elem.tail.strip())
    return " ".join(p for p in parts if p)

def classify_section(head_text):
    """Return canonical section type from heading text."""
    h = head_text.lower().strip()
    if re.search(r'\bintro', h):
        return "intro"
    if re.search(r'\bmethod', h):
        return "methods"
    if re.search(r'\bdiscuss', h):
        return "discussion"
    if re.search(r'\bconclus', h):
        return "conclusion"
    return None

records = []

xml_files = sorted(f for f in os.listdir(XML_DIR) if f.endswith(".xml"))
print(f"Processing {len(xml_files)} XML files...")

for fname in xml_files:
    article_id = fname.replace(".xml", "")
    path = os.path.join(XML_DIR, fname)

    try:
        tree = ET.parse(path)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"  PARSE ERROR: {fname}: {e}")
        records.append({"article_id": article_id, "parse_error": True,
                         "intro": None, "methods": None, "discussion": None})
        continue

    body = root.find(".//tei:body", NS)
    sections = {"intro": [], "methods": [], "discussion": [], "conclusion": []}

    if body is not None:
        for div in body.findall(".//tei:div", NS):
            head = div.find("tei:head", NS)
            if head is None or not head.text:
                continue
            stype = classify_section(head.text)
            if stype:
                text = get_text(div).strip()
                if text:
                    sections[stype].append(text)

    # Merge discussion + conclusion
    disc_text = " ".join(sections["discussion"] + sections["conclusion"]).strip()

    rec = {
        "article_id": article_id,
        "parse_error": False,
        "intro":       " ".join(sections["intro"]).strip()     or None,
        "methods":     " ".join(sections["methods"]).strip()   or None,
        "discussion":  disc_text or None,
    }
    records.append(rec)

    has = [k for k in ("intro","methods","discussion") if rec[k]]
    print(f"  {article_id}: {', '.join(has) if has else 'NO SECTIONS FOUND'}")

out_path = os.path.join(OUT_DIR, "sections.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(records, f, ensure_ascii=False, indent=2)

n_intro  = sum(1 for r in records if r.get("intro"))
n_meth   = sum(1 for r in records if r.get("methods"))
n_disc   = sum(1 for r in records if r.get("discussion"))
n_err    = sum(1 for r in records if r.get("parse_error"))
print(f"\nDone. Saved {len(records)} records to {out_path}")
print(f"  Intro: {n_intro}  Methods: {n_meth}  Discussion: {n_disc}  Errors: {n_err}")
