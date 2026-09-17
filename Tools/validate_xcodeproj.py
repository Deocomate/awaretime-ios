#!/usr/bin/env python3
"""Parses AwareTime.xcodeproj/project.pbxproj and checks it for consistency.

This catches the mistakes that make Xcode refuse to open a project:
syntax errors, dangling object references and missing files on disk.

    python3 Tools/validate_xcodeproj.py
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "AwareTime.xcodeproj/project.pbxproj"


# --------------------------------------------------------------------------- #
# Minimal OpenStep / NeXTSTEP plist parser
# --------------------------------------------------------------------------- #

class Parser:
    def __init__(self, text: str):
        self.text = text
        self.pos = 0

    def error(self, message: str):
        line = self.text.count("\n", 0, self.pos) + 1
        raise SyntaxError(f"{message} at line {line}")

    def skip(self):
        while self.pos < len(self.text):
            ch = self.text[self.pos]
            if ch in " \t\r\n":
                self.pos += 1
            elif self.text.startswith("//", self.pos):
                end = self.text.find("\n", self.pos)
                self.pos = len(self.text) if end == -1 else end
            elif self.text.startswith("/*", self.pos):
                end = self.text.find("*/", self.pos)
                if end == -1:
                    self.error("unterminated block comment")
                self.pos = end + 2
            else:
                return

    def parse(self):
        self.skip()
        value = self.parse_value()
        self.skip()
        if self.pos != len(self.text):
            self.error("trailing content")
        return value

    def parse_value(self):
        self.skip()
        if self.pos >= len(self.text):
            self.error("unexpected end of input")
        ch = self.text[self.pos]
        if ch == "{":
            return self.parse_dict()
        if ch == "(":
            return self.parse_array()
        if ch == '"':
            return self.parse_quoted()
        return self.parse_bare()

    def parse_dict(self):
        self.pos += 1
        result = {}
        while True:
            self.skip()
            if self.pos >= len(self.text):
                self.error("unterminated dictionary")
            if self.text[self.pos] == "}":
                self.pos += 1
                return result
            key = self.parse_value()
            self.skip()
            if self.pos >= len(self.text) or self.text[self.pos] != "=":
                self.error(f"expected '=' after key {key!r}")
            self.pos += 1
            value = self.parse_value()
            self.skip()
            if self.pos < len(self.text) and self.text[self.pos] == ";":
                self.pos += 1
            else:
                self.error(f"expected ';' after value of {key!r}")
            result[key] = value

    def parse_array(self):
        self.pos += 1
        result = []
        while True:
            self.skip()
            if self.pos >= len(self.text):
                self.error("unterminated array")
            if self.text[self.pos] == ")":
                self.pos += 1
                return result
            result.append(self.parse_value())
            self.skip()
            if self.pos < len(self.text) and self.text[self.pos] == ",":
                self.pos += 1

    def parse_quoted(self):
        self.pos += 1
        chars = []
        while True:
            if self.pos >= len(self.text):
                self.error("unterminated string")
            ch = self.text[self.pos]
            if ch == "\\":
                chars.append(self.text[self.pos + 1])
                self.pos += 2
                continue
            if ch == '"':
                self.pos += 1
                return "".join(chars)
            chars.append(ch)
            self.pos += 1

    def parse_bare(self):
        match = re.compile(r"[A-Za-z0-9_./$:+@~-]+").match(self.text, self.pos)
        if not match:
            self.error(f"unexpected character {self.text[self.pos]!r}")
        self.pos = match.end()
        return match.group(0)


# --------------------------------------------------------------------------- #
# Checks
# --------------------------------------------------------------------------- #

def main() -> int:
    if not PBXPROJ.exists():
        print(f"error: {PBXPROJ} does not exist", file=sys.stderr)
        return 1

    text = PBXPROJ.read_text()
    try:
        root = Parser(text).parse()
    except SyntaxError as error:
        print(f"error: project.pbxproj is not valid: {error}", file=sys.stderr)
        return 1

    problems: list[str] = []
    objects = root["objects"]
    print(f"parsed {len(objects)} objects, objectVersion {root['objectVersion']}")

    # Every referenced object id must exist.
    id_pattern = re.compile(r"^[0-9A-F]{24}$")

    def check_references(value, origin):
        if isinstance(value, str):
            if id_pattern.match(value) and value not in objects:
                problems.append(f"{origin}: dangling reference {value}")
        elif isinstance(value, list):
            for item in value:
                check_references(item, origin)
        elif isinstance(value, dict):
            for key, item in value.items():
                check_references(item, f"{origin}.{key}")

    for oid, obj in objects.items():
        if not id_pattern.match(oid):
            problems.append(f"object id is not 24 hex characters: {oid}")
        if not isinstance(obj, dict) or "isa" not in obj:
            problems.append(f"{oid}: object has no isa")
            continue
        for key, value in obj.items():
            if key in ("buildSettings", "attributes"):
                continue
            check_references(value, f"{oid}({obj['isa']}).{key}")

    root_object = root.get("rootObject")
    if root_object not in objects:
        problems.append("rootObject is missing from objects")

    project = objects.get(root_object, {})
    targets = project.get("targets", [])
    print(f"targets: {len(targets)}")

    # Resolve each file reference back to a path on disk through its group.
    parent_of: dict[str, str] = {}
    for oid, obj in objects.items():
        if obj.get("isa") == "PBXGroup":
            for child in obj.get("children", []):
                parent_of[child] = oid

    def resolve(oid: str) -> str:
        parts = []
        node = oid
        while node is not None:
            obj = objects[node]
            segment = obj.get("path")
            if segment:
                parts.append(segment)
            node = parent_of.get(node)
        return "/".join(reversed(parts))

    checked = 0
    for oid, obj in objects.items():
        if obj.get("isa") != "PBXFileReference":
            continue
        if obj.get("sourceTree") == "BUILT_PRODUCTS_DIR":
            continue
        relative = resolve(oid)
        if not relative:
            problems.append(f"{oid}: file reference has no resolvable path")
            continue
        if not (ROOT / relative).exists():
            problems.append(f"{oid}: {relative} does not exist on disk")
        checked += 1
    print(f"file references resolved to disk: {checked}")

    # Each target must have sources, a product and a configuration list.
    swift_files = {
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*.swift")
        if ".build" not in p.parts
    }
    compiled: set[str] = set()

    for target_id in targets:
        target = objects[target_id]
        name = target.get("name")
        if target.get("buildConfigurationList") not in objects:
            problems.append(f"{name}: missing buildConfigurationList")
        if target.get("productReference") not in objects:
            problems.append(f"{name}: missing productReference")
        phases = [objects[p] for p in target.get("buildPhases", [])]
        sources = [p for p in phases if p.get("isa") == "PBXSourcesBuildPhase"]
        if not sources:
            problems.append(f"{name}: no sources build phase")
            continue
        count = 0
        for build_file_id in sources[0].get("files", []):
            build_file = objects[build_file_id]
            ref = build_file.get("fileRef")
            if ref not in objects:
                problems.append(f"{name}: build file with dangling fileRef")
                continue
            compiled.add(resolve(ref))
            count += 1
        if count == 0:
            problems.append(f"{name}: sources build phase is empty")
        print(f"  {name}: {count} source files")

    orphans = sorted(swift_files - compiled)
    if orphans:
        problems.append(
            "swift files not compiled into any target: " + ", ".join(orphans)
        )

    # The app must embed every extension exactly once.
    app_targets = [
        objects[t] for t in targets
        if objects[t].get("productType") == "com.apple.product-type.application"
    ]
    if len(app_targets) != 1:
        problems.append(f"expected exactly one application target, found {len(app_targets)}")
    else:
        embed = [
            objects[p] for p in app_targets[0].get("buildPhases", [])
            if objects[p].get("isa") == "PBXCopyFilesBuildPhase"
        ]
        if not embed:
            problems.append("app target has no Embed Foundation Extensions phase")
        else:
            embedded = len(embed[0].get("files", []))
            expected = len(targets) - 1
            if embedded != expected:
                problems.append(f"embed phase has {embedded} extensions, expected {expected}")
            if embed[0].get("dstSubfolderSpec") != "13":
                problems.append("embed phase dstSubfolderSpec should be 13 (PlugIns)")
            print(f"  embedded extensions: {embedded}")

    if problems:
        print("\nFAILED:")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("\nproject.pbxproj looks consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
